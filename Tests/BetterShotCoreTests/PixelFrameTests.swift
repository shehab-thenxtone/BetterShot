import CoreGraphics
import Testing
@testable import BetterShotCore

struct PixelFrameTests {
    @Test func requiresPositiveSizeAndMatchingByteCount() {
        #expect(PixelFrame(width: 2, height: 2, rgba: [UInt8](repeating: 0, count: 16)) != nil)
        #expect(PixelFrame(width: 2, height: 2, rgba: [UInt8](repeating: 0, count: 15)) == nil)
        #expect(PixelFrame(width: 0, height: 2, rgba: []) == nil)
        #expect(PixelFrame(width: 2, height: -1, rgba: []) == nil)
    }

    @Test func roundTripsThroughACGImage() throws {
        var bytes: [UInt8] = []
        for index in 0..<6 { bytes += [UInt8(index * 40), UInt8(255 - index * 40), UInt8(index * 10), 255] }
        let frame = try #require(PixelFrame(width: 3, height: 2, rgba: bytes))

        let image = try #require(frame.makeImage())
        #expect(image.width == 3 && image.height == 2)
        #expect(PixelFrame(image: image) == frame)
    }

    @Test func readsPixelsFromAnImageWithATopLeftOrigin() throws {
        // Draw red in the top half of a 4x4 image (CoreGraphics y runs upward, so the top half is y 2...4).
        let context = try #require(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 2, width: 4, height: 2))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))

        let image = try #require(context.makeImage())
        let frame = try #require(PixelFrame(image: image))

        #expect(Array(frame.rgba[0..<4]) == [255, 0, 0, 255]) // first row = top = red
        #expect(Array(frame.rgba[(3 * 4 * 4)..<(3 * 4 * 4 + 4)]) == [0, 0, 255, 255]) // last row = bottom = blue
    }
}
