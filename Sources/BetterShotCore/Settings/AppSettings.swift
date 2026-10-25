import Foundation

/// Where the cloud icon's one-click action sends a capture (requirements §4.9).
public enum StorageTarget: String, Codable, CaseIterable, Sendable {
    case local, googleDrive, oneDrive, iCloud
}

public enum GIFExportMode: Equatable, Codable, Sendable {
    case auto
    case manual(GIFExportSettings)
}

/// All user preferences as one value. Hotkeys and per-destination account state are added in later phases.
public struct AppSettings: Equatable, Codable, Sendable {
    public static let popupAutoDismissRange: ClosedRange<Double> = 2...30

    public let filenameTemplate: FilenameTemplate
    public let popupAutoDismissSeconds: Double
    public let defaultStorageTarget: StorageTarget
    public let gifExportMode: GIFExportMode
    public let opensEditorAfterCapture: Bool

    public init(
        filenameTemplate: FilenameTemplate = .default,
        popupAutoDismissSeconds: Double = 6,
        defaultStorageTarget: StorageTarget = .local,
        gifExportMode: GIFExportMode = .auto,
        opensEditorAfterCapture: Bool = false
    ) {
        self.filenameTemplate = filenameTemplate
        self.popupAutoDismissSeconds = min(
            max(popupAutoDismissSeconds, Self.popupAutoDismissRange.lowerBound),
            Self.popupAutoDismissRange.upperBound
        )
        self.defaultStorageTarget = defaultStorageTarget
        self.gifExportMode = gifExportMode
        self.opensEditorAfterCapture = opensEditorAfterCapture
    }

    // Decoding tolerates missing keys (older saved settings) and re-applies clamping via `init`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        self.init(
            filenameTemplate: try container.decodeIfPresent(FilenameTemplate.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate,
            popupAutoDismissSeconds: try container.decodeIfPresent(Double.self, forKey: .popupAutoDismissSeconds) ?? defaults.popupAutoDismissSeconds,
            defaultStorageTarget: try container.decodeIfPresent(StorageTarget.self, forKey: .defaultStorageTarget) ?? defaults.defaultStorageTarget,
            gifExportMode: try container.decodeIfPresent(GIFExportMode.self, forKey: .gifExportMode) ?? defaults.gifExportMode,
            opensEditorAfterCapture: try container.decodeIfPresent(Bool.self, forKey: .opensEditorAfterCapture) ?? defaults.opensEditorAfterCapture
        )
    }
}
