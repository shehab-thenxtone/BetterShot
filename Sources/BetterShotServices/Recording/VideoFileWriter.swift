import AVFoundation
import CoreVideo
import Foundation

public enum RecordingError: Error, Equatable, LocalizedError, Sendable {
    case permissionDenied
    case displayNotFound
    case unsupportedTarget
    case cannotCreateFile(String)
    case noFramesRecorded
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "BetterShot needs Screen Recording permission to record the screen."
        case .displayNotFound: "The display to record is no longer available."
        case .unsupportedTarget: "Only an area or a whole display can be recorded."
        case .cannotCreateFile(let reason): "The recording file couldn't be created: \(reason)"
        case .noFramesRecorded: "Nothing was recorded."
        case .failed(let reason): "Recording failed: \(reason)"
        }
    }
}

/// Writes frames to an H.264 MP4. Timestamps are seconds from the start of the recording and must increase.
/// Safe to call from the capture queue while another thread reads `elapsedSeconds` or calls `finish`.
public final class VideoFileWriter: @unchecked Sendable { // every access to mutable state is under `lock`
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let frameDuration: Double
    private let lock = NSLock()
    private var lastSeconds: Double?
    private var didStartSession = false

    public init(url: URL, width: Int, height: Int, framesPerSecond: Int) throws(RecordingError) {
        try? FileManager.default.removeItem(at: url)

        let assetWriter: AVAssetWriter
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw .cannotCreateFile(error.localizedDescription)
        }

        let fps = max(framesPerSecond, 1)
        // Roughly 0.15 bits per pixel per frame: crisp UI text without huge files, clamped to sane limits.
        let bitrate = min(max(Int(Double(width * height * fps) * 0.15), 1_000_000), 40_000_000)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ])
        videoInput.expectsMediaDataInRealTime = true

        guard assetWriter.canAdd(videoInput) else { throw .cannotCreateFile("The video settings aren't supported.") }
        assetWriter.add(videoInput)

        // AVFoundation requires the adaptor to exist before writing starts; creating it afterwards raises an exception.
        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard assetWriter.startWriting() else {
            throw .cannotCreateFile(assetWriter.error?.localizedDescription ?? "Unknown error.")
        }

        writer = assetWriter
        input = videoInput
        adaptor = pixelAdaptor
        frameDuration = 1 / Double(fps)
    }

    public var isReadyForMoreFrames: Bool {
        lock.withLock { input.isReadyForMoreMediaData }
    }

    /// Time of the most recent frame written.
    public var elapsedSeconds: Double {
        lock.withLock { lastSeconds ?? 0 }
    }

    /// False (and the frame is dropped) if the encoder is busy or `seconds` doesn't advance past the last frame.
    @discardableResult
    public func append(_ pixelBuffer: CVPixelBuffer, at seconds: Double) -> Bool {
        lock.withLock {
            if let last = lastSeconds, seconds <= last { return false }
            guard seconds >= 0, input.isReadyForMoreMediaData, writer.status == .writing else { return false }
            if !didStartSession {
                writer.startSession(atSourceTime: .zero)
                didStartSession = true
            }
            guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 600)) else { return false }
            lastSeconds = seconds
            return true
        }
    }

    /// Closes the file and returns its duration in seconds.
    public func finish() async throws(RecordingError) -> Double {
        let duration: Double? = lock.withLock {
            guard didStartSession, let last = lastSeconds else { return nil }
            input.markAsFinished()
            return last + frameDuration
        }
        guard let duration else {
            writer.cancelWriting()
            throw .noFramesRecorded
        }

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw .failed(writer.error?.localizedDescription ?? "The video couldn't be finished.")
        }
        return duration
    }
}
