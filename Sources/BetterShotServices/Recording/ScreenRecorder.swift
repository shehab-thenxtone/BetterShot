import AVFoundation
import BetterShotCore
import CoreMedia
import Foundation
import ScreenCaptureKit

public struct RecordingResult: Equatable, Sendable {
    public let url: URL
    public let duration: Double

    public init(url: URL, duration: Double) {
        self.url = url
        self.duration = duration
    }
}

/// Records a display or a region of it to an MP4 with ScreenCaptureKit. BetterShot's own windows (the recording
/// controls) are excluded from the picture. Pausing drops frames and closes the gap so the video skips the pause.
public final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable { // mutable state is under `lock`
    private let lock = NSLock()
    private let sampleQueue = DispatchQueue(label: "com.bettershot.recorder.samples", qos: .userInteractive)
    private var stream: SCStream?
    private var writer: VideoFileWriter?
    private var outputURL: URL?
    private var clock = RecordingClock()
    private var streamError: String?

    public override init() {
        super.init()
    }

    public var isRecording: Bool { lock.withLock { stream != nil } }
    public var isPaused: Bool { lock.withLock { clock.isPaused } }

    /// Seconds of video written so far, excluding pauses.
    public var elapsedSeconds: Double { lock.withLock { writer?.elapsedSeconds ?? 0 } }

    public func start(_ request: CaptureRequest, to url: URL, framesPerSecond: Int = 30) async throws(RecordingError) {
        guard ScreenRecordingPermission.isGranted else { throw .permissionDenied }
        do {
            try await begin(request, to: url, framesPerSecond: framesPerSecond)
        } catch let error as RecordingError {
            throw error
        } catch {
            throw .failed(error.localizedDescription)
        }
    }

    public func pause() {
        lock.withLock { clock.pause(at: Self.hostSeconds()) }
    }

    public func resume() {
        lock.withLock { clock.resume(at: Self.hostSeconds()) }
    }

    /// Stops recording, closes the file and returns it.
    public func stop() async throws(RecordingError) -> RecordingResult {
        let (activeStream, activeWriter, url) = lock.withLock { () -> (SCStream?, VideoFileWriter?, URL?) in
            let current = (stream, writer, outputURL)
            stream = nil
            return current
        }
        guard let activeStream, let activeWriter, let url else { throw .failed("Not recording.") }

        try? await activeStream.stopCapture() // already stopped if the system ended the stream
        sampleQueue.sync {} // let queued frames finish before closing the file

        defer { lock.withLock { writer = nil; outputURL = nil } }
        do {
            let duration = try await activeWriter.finish()
            return RecordingResult(url: url, duration: duration)
        } catch {
            if let reason = lock.withLock({ streamError }), error == .noFramesRecorded {
                throw .failed(reason)
            }
            throw error
        }
    }

    // MARK: SCStreamOutput / SCStreamDelegate

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard
            type == .screen, sampleBuffer.isValid,
            let attachments = (CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
            let statusValue = attachments[.status] as? Int, SCFrameStatus(rawValue: statusValue) == .complete,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let (time, activeWriter) = lock.withLock { (clock.retime(timestamp), writer) }
        guard let time, let activeWriter else { return }
        activeWriter.append(pixelBuffer, at: time)
    }

    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        lock.withLock { streamError = error.localizedDescription }
    }

    // MARK: Private

    private func begin(_ request: CaptureRequest, to url: URL, framesPerSecond: Int) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let displayID: UInt32
        let region: CGRect?
        let scale: CGFloat
        switch request {
        case .display(let id, let displayScale):
            (displayID, region, scale) = (id, nil, displayScale)
        case .area(let id, let rect, let displayScale):
            (displayID, region, scale) = (id, rect, displayScale)
        case .window:
            throw RecordingError.unsupportedTarget
        }
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw RecordingError.displayNotFound
        }

        let source = region ?? CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
        let pixelWidth = Self.evenPixels(source.width * scale)
        let pixelHeight = Self.evenPixels(source.height * scale)
        let fps = max(framesPerSecond, 1)

        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = source
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        configuration.showsCursor = true
        configuration.queueDepth = 6
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let newWriter = try VideoFileWriter(url: url, width: pixelWidth, height: pixelHeight, framesPerSecond: fps)
        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)

        lock.withLock {
            writer = newWriter
            stream = newStream
            outputURL = url
            clock = RecordingClock()
            streamError = nil
        }
        try await newStream.startCapture()
    }

    /// H.264 needs even dimensions.
    private static func evenPixels(_ value: CGFloat) -> Int {
        max(2, Int(value.rounded()) / 2 * 2)
    }

    /// The host clock ScreenCaptureKit stamps its frames with, so pauses and frame timestamps share a timebase.
    private static func hostSeconds() -> Double {
        CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
    }
}
