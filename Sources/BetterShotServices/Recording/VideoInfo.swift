import AVFoundation
import Foundation

/// What the GIF export (and its size estimate) needs to know about a recording.
public struct VideoInfo: Equatable, Sendable {
    public let duration: Double
    public let width: Int
    public let height: Int
    public let framesPerSecond: Int

    public init(duration: Double, width: Int, height: Int, framesPerSecond: Int) {
        self.duration = duration
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
    }

    public static func load(from url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFExportError.unreadableVideo("\(url.lastPathComponent) has no video track.")
        }
        let size = try await track.load(.naturalSize)
        let frameRate = try await track.load(.nominalFrameRate)

        return VideoInfo(
            duration: duration.isFinite ? max(duration, 0) : 0,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            framesPerSecond: frameRate > 0 ? max(1, Int(frameRate.rounded())) : 30
        )
    }
}
