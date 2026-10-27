import AVFoundation
import BetterShotCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum GIFExportError: Error, Equatable, LocalizedError, Sendable {
    case unreadableVideo(String)
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableVideo(let reason): "The recording couldn't be read: \(reason)"
        case .cancelled: "The export was cancelled."
        case .failed(let reason): "The GIF couldn't be created: \(reason)"
        }
    }
}

/// Converts a recording to an animated GIF with the user's frame rate, colour depth, dithering and scale
/// (requirements §3.1a). ImageIO can't limit a GIF's palette or dither, so frames are quantised here first and
/// ImageIO then only has to write colours that already fit the chosen depth.
public struct GIFExporter: Sendable {
    private static let paletteSampleFrames = 12
    private static let paletteSamplePixelBudget = 200_000

    public init() {}

    /// Writes the GIF to `output`. `progress` receives 0…1 after each frame. Cancelling the calling task stops
    /// the export and removes the partial file.
    public func export(
        video: URL,
        to output: URL,
        settings: GIFExportSettings,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws(GIFExportError) {
        do {
            try await run(video: video, output: output, settings: settings, progress: progress)
        } catch let error as GIFExportError {
            try? FileManager.default.removeItem(at: output)
            throw error
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: output)
            throw .cancelled
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw .failed(error.localizedDescription)
        }
    }

    // MARK: Pipeline

    private func run(video: URL, output: URL, settings: GIFExportSettings, progress: @escaping @Sendable (Double) -> Void) async throws {
        let info = try await VideoInfo.load(from: video)
        let times = GIFTiming.frameTimes(duration: info.duration, framesPerSecond: settings.framesPerSecond)

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero // exact frames, not the nearest keyframe
        generator.requestedTimeToleranceAfter = .zero
        let scale = CGFloat(settings.scale.rawValue)
        generator.maximumSize = CGSize(width: (CGFloat(info.width) * scale).rounded(), height: (CGFloat(info.height) * scale).rounded())

        // Pass 1: one palette for the whole GIF, from a handful of frames spread across the recording.
        let mapper = PaletteMapper(palette: try await palette(from: generator, times: times, colorCount: settings.colorDepth.colorCount))

        // Pass 2: recolour every frame and hand it to ImageIO.
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, times.count, nil) else {
            throw GIFExportError.failed("The output file couldn't be created.")
        }
        let fileProperties: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        let frameProperties: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: GIFTiming.frameDelay(framesPerSecond: settings.framesPerSecond)]]

        for (index, time) in times.enumerated() {
            try Task.checkCancellation()
            let frame = try await Self.rgbaFrame(from: generator, at: time)
            let recoloured = mapper.map(rgba: frame.bytes, width: frame.width, dithering: settings.isDitheringEnabled)
            guard let image = Self.makeImage(rgba: recoloured, width: frame.width, height: frame.height) else {
                throw GIFExportError.failed("A frame couldn't be encoded.")
            }
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            progress(Double(index + 1) / Double(times.count))
        }
        guard CGImageDestinationFinalize(destination) else {
            throw GIFExportError.failed("The GIF couldn't be written.")
        }
    }

    private func palette(from generator: AVAssetImageGenerator, times: [Double], colorCount: Int) async throws -> [RGB] {
        let sampleTimes = Self.evenlySpaced(times, count: Self.paletteSampleFrames)
        let pixelsPerFrame = Self.paletteSamplePixelBudget / max(sampleTimes.count, 1)

        var samples: [UInt8] = []
        for time in sampleTimes {
            try Task.checkCancellation()
            let frame = try await Self.rgbaFrame(from: generator, at: time)
            samples += Self.subsampled(frame.bytes, maxPixels: pixelsPerFrame)
        }
        return PaletteQuantizer.palette(from: samples, maxColors: colorCount)
    }

    // MARK: Helpers

    private static func rgbaFrame(from generator: AVAssetImageGenerator, at seconds: Double) async throws -> (bytes: [UInt8], width: Int, height: Int) {
        let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { pointer -> Bool in
            guard let context = CGContext(
                data: pointer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { throw GIFExportError.failed("A frame couldn't be read.") }
        return (bytes, image.width, image.height)
    }

    private static func makeImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    private static func evenlySpaced(_ times: [Double], count: Int) -> [Double] {
        guard times.count > count, count > 0 else { return times }
        return (0..<count).map { times[$0 * times.count / count] }
    }

    /// Every n-th pixel so at most about `maxPixels` remain.
    private static func subsampled(_ rgba: [UInt8], maxPixels: Int) -> [UInt8] {
        let pixelCount = rgba.count / 4
        guard maxPixels > 0, pixelCount > maxPixels else { return rgba }
        let step = pixelCount / maxPixels
        var result: [UInt8] = []
        result.reserveCapacity(maxPixels * 4)
        for pixel in stride(from: 0, to: pixelCount, by: step) {
            result.append(contentsOf: rgba[(pixel * 4)..<(pixel * 4 + 4)])
        }
        return result
    }
}
