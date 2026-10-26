import BetterShotCore
import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import BetterShotServices

struct VisionOCRProviderTests {
    /// White canvas with `text` in large black type, so recognition is unambiguous.
    private func textImage(_ text: String, width: Int = 520, height: Int = 140) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("HelveticaNeue" as CFString, 64, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: 24, y: 48)
        CTLineDraw(line, context)
        return context.makeImage()!
    }

    @Test func recognizesEnglishTextAndItsWords() async throws {
        let image = textImage("Hello World")
        let lines = try await VisionOCRProvider().recognize(in: image, languages: [.english])

        let text = TextAssembler.plainText(from: lines).lowercased()
        #expect(text.contains("hello"))
        #expect(text.contains("world"))

        let words = lines.flatMap(\.words)
        #expect(words.count >= 2)
        #expect(words[0].rect.minX < words[1].rect.minX) // left to right
    }

    @Test func rectanglesAreInImagePixelsWithATopLeftOrigin() async throws {
        let image = textImage("Hello World")
        let lines = try await VisionOCRProvider().recognize(in: image, languages: [.english])
        let line = try #require(lines.first)

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height).insetBy(dx: -2, dy: -2)
        #expect(bounds.contains(line.rect))
        // The text baseline sits near the bottom third of a 140pt image, so in top-left coordinates the line
        // is in the lower half — not the upper half a bottom-left origin would give.
        #expect(line.rect.midY > CGFloat(image.height) / 2)
    }

    @Test func aBlankImageHasNoText() async throws {
        let lines = try await VisionOCRProvider().recognize(in: textImage(""), languages: [.english])
        #expect(TextAssembler.plainText(from: lines).isEmpty)
    }
}
