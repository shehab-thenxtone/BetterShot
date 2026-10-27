import AVFoundation
import CoreVideo
import Foundation
import Testing
@testable import BetterShotServices

/// A BGRA frame of one flat shade.
func makeTestPixelBuffer(width: Int, height: Int, shade: UInt8) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
    let pixelBuffer = buffer!
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    memset(CVPixelBufferGetBaseAddress(pixelBuffer), Int32(shade), CVPixelBufferGetBytesPerRow(pixelBuffer) * height)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    return pixelBuffer
}

struct VideoFileWriterTests {
    private func makeURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("BetterShotTests-\(UUID().uuidString).mp4")
    }

    /// Appends with a short wait if the encoder isn't ready, like real capture would drop a frame instead.
    private func appendWhenReady(_ writer: VideoFileWriter, _ buffer: CVPixelBuffer, at seconds: Double) async throws -> Bool {
        var attempts = 0
        while !writer.isReadyForMoreFrames, attempts < 300 {
            try await Task.sleep(for: .milliseconds(10))
            attempts += 1
        }
        return writer.append(buffer, at: seconds)
    }

    @Test func writesAPlayableMP4OfTheRightSizeAndLength() async throws {
        let url = makeURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try VideoFileWriter(url: url, width: 160, height: 96, framesPerSecond: 30)

        for index in 0..<30 {
            let appended = try await appendWhenReady(writer, makeTestPixelBuffer(width: 160, height: 96, shade: UInt8(index * 8)), at: Double(index) / 30)
            #expect(appended)
        }
        let reportedDuration = try await writer.finish()

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 1) < 0.2)
        #expect(abs(reportedDuration - 1) < 0.2)

        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(size == CGSize(width: 160, height: 96))
    }

    @Test func framesThatDoNotAdvanceTimeAreRejected() async throws {
        let url = makeURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try VideoFileWriter(url: url, width: 64, height: 64, framesPerSecond: 30)
        let frame = makeTestPixelBuffer(width: 64, height: 64, shade: 100)

        #expect(try await appendWhenReady(writer, frame, at: 0))
        #expect(!writer.append(frame, at: 0)) // same timestamp
        #expect(!writer.append(frame, at: -1)) // going backwards
        _ = try? await writer.finish()
    }

    @Test func elapsedTimeFollowsTheLatestFrame() async throws {
        let url = makeURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try VideoFileWriter(url: url, width: 64, height: 64, framesPerSecond: 30)
        #expect(writer.elapsedSeconds == 0)

        _ = try await appendWhenReady(writer, makeTestPixelBuffer(width: 64, height: 64, shade: 1), at: 0)
        _ = try await appendWhenReady(writer, makeTestPixelBuffer(width: 64, height: 64, shade: 2), at: 2.5)
        #expect(writer.elapsedSeconds == 2.5)
        _ = try? await writer.finish()
    }

    @Test func finishingWithoutAnyFramesIsAnError() async throws {
        let url = makeURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try VideoFileWriter(url: url, width: 64, height: 64, framesPerSecond: 30)

        await #expect(throws: RecordingError.noFramesRecorded) {
            _ = try await writer.finish()
        }
    }
}
