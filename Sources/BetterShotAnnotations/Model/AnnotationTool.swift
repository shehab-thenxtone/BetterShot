import Foundation

/// The editor's drawing tools, in toolbar order (requirements §3.3). Crop and Merge are image operations
/// rather than annotation tools, so they live outside this enum.
public enum AnnotationTool: String, CaseIterable, Codable, Sendable {
    case select
    case rectangle
    case filledRectangle
    case ellipse
    case line
    case arrow
    case text
    case pixelate
    case stepCounter
    case marker
    case pen
    case textHighlighter

    /// Default single-letter shortcut (assignable in a later release).
    public var defaultKey: String {
        switch self {
        case .select: "v"
        case .rectangle: "r"
        case .filledRectangle: "f"
        case .ellipse: "e"
        case .line: "l"
        case .arrow: "a"
        case .text: "t"
        case .pixelate: "p"
        case .stepCounter: "n"
        case .marker: "m"
        case .pen: "d"
        case .textHighlighter: "h"
        }
    }

    public static func tool(forKey key: String) -> AnnotationTool? {
        allCases.first { $0.defaultKey == key.lowercased() }
    }

    /// Style a tool starts with before the user changes it.
    public var defaultStyle: AnnotationStyle {
        switch self {
        case .marker: AnnotationStyle(color: AnnotationColor.yellow.withAlpha(0.45), lineWeight: .medium)
        case .textHighlighter: AnnotationStyle(color: AnnotationColor.yellow.withAlpha(0.45))
        case .filledRectangle: AnnotationStyle(color: .black)
        case .select, .rectangle, .ellipse, .line, .arrow, .text, .pixelate, .stepCounter, .pen: AnnotationStyle()
        }
    }
}

/// The last style used with each tool, so colour and weight persist between editor sessions (requirements §3.3).
public struct ToolStyles: Equatable, Codable, Sendable {
    public static let defaults = ToolStyles(overrides: [:])

    private let overrides: [AnnotationTool: AnnotationStyle]

    private init(overrides: [AnnotationTool: AnnotationStyle]) {
        self.overrides = overrides
    }

    public func style(for tool: AnnotationTool) -> AnnotationStyle {
        overrides[tool] ?? tool.defaultStyle
    }

    public func setting(_ style: AnnotationStyle, for tool: AnnotationTool) -> ToolStyles {
        var updated = overrides
        updated[tool] = style
        return ToolStyles(overrides: updated)
    }

    // MARK: Codable — {"styles": {"<tool>": <style>}}; unknown tool names are ignored.

    private enum CodingKeys: String, CodingKey { case styles }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saved = try container.decodeIfPresent([String: AnnotationStyle].self, forKey: .styles) ?? [:]
        var resolved: [AnnotationTool: AnnotationStyle] = [:]
        for (name, style) in saved {
            if let tool = AnnotationTool(rawValue: name) { resolved[tool] = style }
        }
        self.init(overrides: resolved)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let saved = Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) })
        try container.encode(saved, forKey: .styles)
    }
}
