import AVFoundation
import BetterShotCore
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import BetterShotServices

struct GIFExporterTests {
    private let width = 160
    private let height = 96

    /// One second of 30 fps video with a colour gradient that changes every frame (thousands of distinct colours).
    private func makeVideo() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BetterShotTests-\(UUID().uuidString).mp4")
        let writer = try VideoFileWriter(url: url, width: width, height: height, framesPerSecond: 30)

        for index in 0..<30 {
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
            let pixelBuffer = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            let base = try #require(CVPixelBufferGetBaseAddress(pixelBuffer)).assumingMemoryBound(to: UInt8.self)
            let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
            for y in 0..<height {
                for x in 0..<width {
                    let pixel = base + y * rowBytes + x * 4
                    pixel[0] = UInt8((index * 8) & 255) // B
                    pixel[1] = UInt8(y * 255 / height) // G
                    pixel[2] = UInt8(x * 255 / width) // R
                    pixel[3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            var attempts = 0
            while !writer.isReadyForMoreFrames, attempts < 300 {
                try await Task.sleep(for: .milliseconds(10))
                attempts += 1
            }
            writer.append(pixelBuffer, at: Double(index) / 30)
        }
        _ = try await writer.finish()
        return url
    }

    private func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("BetterShotTests-\(UUID().uuidString).gif")
    }

    private func distinctColors(in image: CGImage) -> Int {
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        buffer.withUnsafeMutableBytes { pointer in
            CGContext(
                data: pointer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var colors = Set<UInt32>()
        for index in stride(from: 0, to: buffer.count, by: 4) {
            colors.insert(UInt32(buffer[index]) << 16 | UInt32(buffer[index + 1]) << 8 | UInt32(buffer[index + 2]))
        }
        return colors.count
    }

    @Test func exportsAGIFWithTheRequestedFrameCountSizeAndColourLimit() async throws {
        let video = try await makeVideo()
        let output = makeOutputURL()
        defer { try? FileManager.default.removeItem(at: video); try? FileManager.default.removeItem(at: output) }

        let settings = GIFExportSettings(framesPerSecond: 10, colorDepth: .low, isDitheringEnabled: false, scale: .half)
        try await GIFExporter().export(video: video, to: output, settings: settings)

        let data = try Data(contentsOf: output)
        let header = String(decoding: data.prefix(6), as: UTF8.self)
        #expect(header.hasPrefix("GIF8"), "unexpected file header: \(header)")

        let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 10) // 1 s at 10 fps

        // It must actually animate: every frame carries its delay (0.1 s at 10 fps) and the loop count is "forever".
        let fileGIF = (CGImageSourceCopyProperties(source, nil) as? [CFString: Any])?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        #expect((fileGIF?[kCGImagePropertyGIFLoopCount] as? Int) == 0)
        let frameGIF = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        #expect(abs(((frameGIF?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0) - 0.1) < 0.001)
        let frame = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(frame.width == 80 && frame.height == 48) // 50% scale
        #expect(distinctColors(in: frame) <= 64) // "Low" = 64 colours
    }

    @Test func ditheredExportsStayWithinTheColourLimitToo() async throws {
        let video = try await makeVideo()
        let output = makeOutputURL()
        defer { try? FileManager.default.removeItem(at: video); try? FileManager.default.removeItem(at: output) }

        let settings = GIFExportSettings(framesPerSecond: 10, colorDepth: .medium, isDitheringEnabled: true, scale: .half)
        try await GIFExporter().export(video: video, to: output, settings: settings)

        let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let frame = try #require(CGImageSourceCreateImageAtIndex(source, 3, nil))
        #expect(distinctColors(in: frame) <= 128)
    }

    @Test func moreColoursAndFramesMakeALargerFile() async throws {
        let video = try await makeVideo()
        let small = makeOutputURL()
        let large = makeOutputURL()
        defer { [video, small, large].forEach { try? FileManager.default.removeItem(at: $0) } }

        try await GIFExporter().export(video: video, to: small, settings: GIFExportSettings(framesPerSecond: 10, colorDepth: .low, scale: .half))
        try await GIFExporter().export(video: video, to: large, settings: GIFExportSettings(framesPerSecond: 20, colorDepth: .high, scale: .half))

        let smallSize = try FileManager.default.attributesOfItem(atPath: small.path)[.size] as? Int ?? 0
        let largeSize = try FileManager.default.attributesOfItem(atPath: large.path)[.size] as? Int ?? 0
        #expect(largeSize > smallSize)
    }

    @Test func reportsProgressUpToCompletion() async throws {
        let video = try await makeVideo()
        let output = makeOutputURL()
        defer { try? FileManager.default.removeItem(at: video); try? FileManager.default.removeItem(at: output) }

        let recorder = ProgressRecorder()
        try await GIFExporter().export(
            video: video, to: output,
            settings: GIFExportSettings(framesPerSecond: 10, colorDepth: .low, scale: .half),
            progress: { recorder.record($0) }
        )

        let values = recorder.values
        #expect(!values.isEmpty)
        #expect(values == values.sorted())
        #expect(values.last == 1)
    }

    @Test func videoInfoReportsDurationSizeAndFrameRate() async throws {
        let video = try await makeVideo()
        defer { try? FileManager.default.removeItem(at: video) }

        let info = try await VideoInfo.load(from: video)
        #expect(abs(info.duration - 1) < 0.2)
        #expect(info.width == width && info.height == height)
        #expect(info.framesPerSecond == 30)
    }

    @Test func anUnreadableFileFailsCleanly() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString).mp4")
        await #expect(throws: GIFExportError.self) {
            try await GIFExporter().export(video: missing, to: makeOutputURL(), settings: GIFExportSettings())
        }
    }
}

/// Collects progress callbacks, which arrive from the exporter's task.
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    func record(_ value: Double) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(value)
    }

    var values: [Double] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }
}
