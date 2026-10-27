import Foundation

/// Where the cloud icon's one-click action sends a capture (requirements §4.9).
public enum StorageTarget: String, Codable, CaseIterable, Sendable {
    case local, googleDrive, oneDrive, iCloud, whatsApp, telegram

    /// The chat apps are shares, not file hosts: there is no link to copy.
    public var messagingApp: MessagingApp? {
        switch self {
        case .whatsApp: .whatsApp
        case .telegram: .telegram
        default: nil
        }
    }

    /// The linked-account host behind this target, if it has one.
    public var cloudProvider: CloudProvider? {
        switch self {
        case .googleDrive: .googleDrive
        case .oneDrive: .oneDrive
        default: nil
        }
    }
}

public enum GIFExportMode: Equatable, Codable, Sendable {
    case auto
    case manual(GIFExportSettings)

    /// The concrete export settings. Auto derives them from the source video's frame rate (requirements §3.1a).
    public func settings(sourceFramesPerSecond: Int) -> GIFExportSettings {
        switch self {
        case .auto: .auto(sourceFramesPerSecond: sourceFramesPerSecond)
        case .manual(let settings): settings
        }
    }
}

/// All user preferences as one value. Per-destination account state is added in a later phase.
public struct AppSettings: Equatable, Codable, Sendable {
    public static let popupAutoDismissRange: ClosedRange<Double> = 2...30

    public let filenameTemplate: FilenameTemplate
    public let popupAutoDismissSeconds: Double
    public let defaultStorageTarget: StorageTarget
    public let gifExportMode: GIFExportMode
    public let opensEditorAfterCapture: Bool
    public let hotkeys: HotkeyBindings
    public let launchesAtLogin: Bool
    public let selfTimerDelay: SelfTimerDelay
    /// When false, Hide Desktop Icons is temporary: icons come back after the next capture (requirements §3.1 item 10).
    public let keepsDesktopIconsHidden: Bool

    public init(
        filenameTemplate: FilenameTemplate = .default,
        popupAutoDismissSeconds: Double = 6,
        defaultStorageTarget: StorageTarget = .local,
        gifExportMode: GIFExportMode = .auto,
        opensEditorAfterCapture: Bool = false,
        hotkeys: HotkeyBindings = .defaults,
        launchesAtLogin: Bool = false,
        selfTimerDelay: SelfTimerDelay = .five,
        keepsDesktopIconsHidden: Bool = false
    ) {
        self.filenameTemplate = filenameTemplate
        self.popupAutoDismissSeconds = min(
            max(popupAutoDismissSeconds, Self.popupAutoDismissRange.lowerBound),
            Self.popupAutoDismissRange.upperBound
        )
        self.defaultStorageTarget = defaultStorageTarget
        self.gifExportMode = gifExportMode
        self.opensEditorAfterCapture = opensEditorAfterCapture
        self.hotkeys = hotkeys
        self.launchesAtLogin = launchesAtLogin
        self.selfTimerDelay = selfTimerDelay
        self.keepsDesktopIconsHidden = keepsDesktopIconsHidden
    }

    /// Copy with the given fields replaced. Goes through `init`, so clamping still applies.
    public func updating(
        filenameTemplate: FilenameTemplate? = nil,
        popupAutoDismissSeconds: Double? = nil,
        defaultStorageTarget: StorageTarget? = nil,
        gifExportMode: GIFExportMode? = nil,
        opensEditorAfterCapture: Bool? = nil,
        hotkeys: HotkeyBindings? = nil,
        launchesAtLogin: Bool? = nil,
        selfTimerDelay: SelfTimerDelay? = nil,
        keepsDesktopIconsHidden: Bool? = nil
    ) -> AppSettings {
        AppSettings(
            filenameTemplate: filenameTemplate ?? self.filenameTemplate,
            popupAutoDismissSeconds: popupAutoDismissSeconds ?? self.popupAutoDismissSeconds,
            defaultStorageTarget: defaultStorageTarget ?? self.defaultStorageTarget,
            gifExportMode: gifExportMode ?? self.gifExportMode,
            opensEditorAfterCapture: opensEditorAfterCapture ?? self.opensEditorAfterCapture,
            hotkeys: hotkeys ?? self.hotkeys,
            launchesAtLogin: launchesAtLogin ?? self.launchesAtLogin,
            selfTimerDelay: selfTimerDelay ?? self.selfTimerDelay,
            keepsDesktopIconsHidden: keepsDesktopIconsHidden ?? self.keepsDesktopIconsHidden
        )
    }

    // Decoding tolerates missing keys (older saved settings) and re-applies clamping via `init`.
    // An unrecognised self-timer value falls back to the default instead of discarding every other setting.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        self.init(
            filenameTemplate: try container.decodeIfPresent(FilenameTemplate.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate,
            popupAutoDismissSeconds: try container.decodeIfPresent(Double.self, forKey: .popupAutoDismissSeconds) ?? defaults.popupAutoDismissSeconds,
            defaultStorageTarget: try container.decodeIfPresent(StorageTarget.self, forKey: .defaultStorageTarget) ?? defaults.defaultStorageTarget,
            gifExportMode: try container.decodeIfPresent(GIFExportMode.self, forKey: .gifExportMode) ?? defaults.gifExportMode,
            opensEditorAfterCapture: try container.decodeIfPresent(Bool.self, forKey: .opensEditorAfterCapture) ?? defaults.opensEditorAfterCapture,
            hotkeys: try container.decodeIfPresent(HotkeyBindings.self, forKey: .hotkeys) ?? defaults.hotkeys,
            launchesAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchesAtLogin) ?? defaults.launchesAtLogin,
            selfTimerDelay: (try? container.decodeIfPresent(SelfTimerDelay.self, forKey: .selfTimerDelay)) ?? defaults.selfTimerDelay,
            keepsDesktopIconsHidden: try container.decodeIfPresent(Bool.self, forKey: .keepsDesktopIconsHidden) ?? defaults.keepsDesktopIconsHidden
        )
    }
}
