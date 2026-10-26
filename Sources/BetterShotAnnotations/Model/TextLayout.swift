import CoreGraphics
import CoreText
import Foundation

/// Text measuring and line construction shared by hit-testing (`AnnotationKind.bounds`) and the renderer,
/// so what the editor selects is exactly what gets drawn.
enum TextLayout {
    static func font(size: CGFloat, isBold: Bool = false) -> CTFont {
        CTFontCreateWithName((isBold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString, max(size, 1), nil)
    }

    static func lines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    static func lineHeight(of font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }

    static func ctLine(_ text: String, font: CTFont, color: CGColor = CGColor(gray: 0, alpha: 1)) -> CTLine {
        let attributes: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes as [NSAttributedString.Key: Any]))
    }

    static func width(of line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// Size of `text` laid out as one line per "\n".
    static func measure(_ text: String, fontSize: CGFloat) -> CGSize {
        let font = font(size: fontSize)
        let widest = lines(of: text).map { width(of: ctLine($0, font: font)) }.max() ?? 0
        return CGSize(width: widest, height: lineHeight(of: font) * CGFloat(lines(of: text).count))
    }
}
