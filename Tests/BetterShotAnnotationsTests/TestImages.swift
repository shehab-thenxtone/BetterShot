import CoreGraphics

/// Small deterministic images for pixel-level assertions. Pixel (0, 0) is the top-left.
enum TestImage {
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Opaque image whose pixel (x, y) is `color(x, y)` (RGBA bytes).
    static func make(width: Int, height: Int, color: (Int, Int) -> [UInt8]) -> CGImage {
        var buffer = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                buffer[index..<index + 4] = ArraySlice(color(x, y))
            }
        }
        return buffer.withUnsafeMutableBytes { pointer in
            CGContext(
                data: pointer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!.makeImage()!
        }
    }

    static func solid(width: Int, height: Int, _ rgba: [UInt8]) -> CGImage {
        make(width: width, height: height) { _, _ in rgba }
    }

    /// RGBA bytes of one pixel, read back through a bitmap context so any source format is normalised.
    static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        buffer.withUnsafeMutableBytes { pointer in
            CGContext(
                data: pointer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let index = (y * image.width + x) * 4
        return Array(buffer[index..<index + 4])
    }
}
