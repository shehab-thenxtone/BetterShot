import CoreGraphics

/// RGBA with components in 0...1 (sRGB). Plain value type so the model needs no AppKit/SwiftUI colour.
public struct AnnotationColor: Equatable, Hashable, Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    public func withAlpha(_ alpha: Double) -> AnnotationColor {
        AnnotationColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Perceived brightness, used to pick readable text on top of a colour.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    // The editor's colour swatches (the reference toolbar defaults to purple).
    public static let purple = AnnotationColor(red: 0.55, green: 0.27, blue: 0.95)
    public static let scarlet = AnnotationColor(red: 0.95, green: 0.2, blue: 0.2)
    public static let orange = AnnotationColor(red: 1, green: 0.6, blue: 0.1)
    public static let yellow = AnnotationColor(red: 1, green: 0.85, blue: 0.1)
    public static let mint = AnnotationColor(red: 0.2, green: 0.8, blue: 0.5)
    public static let azure = AnnotationColor(red: 0.1, green: 0.5, blue: 1)
    public static let black = AnnotationColor(red: 0, green: 0, blue: 0)
    public static let white = AnnotationColor(red: 1, green: 1, blue: 1)
}

/// How an annotation looks: the editor's colour, line-weight and arrow-style controls (requirements §3.3).
public struct AnnotationStyle: Equatable, Codable, Sendable {
    public enum LineWeight: String, Codable, CaseIterable, Sendable {
        case thin, medium, thick

        /// Stroke width in document points.
        public var points: CGFloat {
            switch self {
            case .thin: 2
            case .medium: 4
            case .thick: 8
            }
        }
    }

    public enum ArrowStyle: String, Codable, CaseIterable, Sendable {
        case solid // filled triangular head
        case open // two-stroke "V" head
    }

    public let color: AnnotationColor
    public let lineWeight: LineWeight
    public let arrowStyle: ArrowStyle

    public init(color: AnnotationColor = .purple, lineWeight: LineWeight = .medium, arrowStyle: ArrowStyle = .solid) {
        self.color = color
        self.lineWeight = lineWeight
        self.arrowStyle = arrowStyle
    }

    public func updating(
        color: AnnotationColor? = nil,
        lineWeight: LineWeight? = nil,
        arrowStyle: ArrowStyle? = nil
    ) -> AnnotationStyle {
        AnnotationStyle(
            color: color ?? self.color,
            lineWeight: lineWeight ?? self.lineWeight,
            arrowStyle: arrowStyle ?? self.arrowStyle
        )
    }
}
