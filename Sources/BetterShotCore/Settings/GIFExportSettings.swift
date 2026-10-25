import Foundation

/// Manual GIF export options (requirements §3.1a).
public struct GIFExportSettings: Equatable, Hashable, Codable, Sendable {
    public static let maxFramesPerSecond = 30
    public static let frameRatePresets = [10, 15, 20, 24, 30]

    public enum ColorDepth: String, Codable, CaseIterable, Sendable {
        case low, medium, high

        public var colorCount: Int {
            switch self {
            case .low: 64
            case .medium: 128
            case .high: 256
            }
        }

        /// Rough compressed bytes per pixel per frame, tuned for UI recordings.
        fileprivate var bytesPerPixel: Double {
            switch self {
            case .low: 0.10
            case .medium: 0.13
            case .high: 0.16
            }
        }
    }

    public enum Scale: Double, Codable, CaseIterable, Sendable {
        case full = 1.0
        case threeQuarters = 0.75
        case half = 0.5
    }

    public let framesPerSecond: Int
    public let colorDepth: ColorDepth
    public let isDitheringEnabled: Bool
    public let scale: Scale

    public init(
        framesPerSecond: Int = 15,
        colorDepth: ColorDepth = .medium,
        isDitheringEnabled: Bool = true,
        scale: Scale = .full
    ) {
        self.framesPerSecond = min(max(framesPerSecond, 1), Self.maxFramesPerSecond)
        self.colorDepth = colorDepth
        self.isDitheringEnabled = isDitheringEnabled
        self.scale = scale
    }

    /// Auto mode: reuse the source frame rate (capped), with the default quality settings.
    public static func auto(sourceFramesPerSecond: Int) -> GIFExportSettings {
        GIFExportSettings(framesPerSecond: sourceFramesPerSecond)
    }

    /// Heuristic estimate for the live "~4.2 MB" label; not an exact encoder prediction.
    public func estimatedByteCount(width: Int, height: Int, duration: TimeInterval) -> Int {
        guard width > 0, height > 0, duration > 0 else { return 0 }
        let pixels = Double(width) * Double(height) * scale.rawValue * scale.rawValue
        let frames = duration * Double(framesPerSecond)
        let ditherPenalty = isDitheringEnabled ? 1.25 : 1.0
        return Int(pixels * frames * colorDepth.bytesPerPixel * ditherPenalty)
    }

    public static func formatted(byteCount: Int) -> String {
        let megabyte = 1_048_576.0
        let kilobyte = 1_024.0
        let bytes = Double(byteCount)
        if bytes >= megabyte {
            return String(format: "~%.1f MB", bytes / megabyte)
        }
        return String(format: "~%.0f KB", bytes / kilobyte)
    }
}
