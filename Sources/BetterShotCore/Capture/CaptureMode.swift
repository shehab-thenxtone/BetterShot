/// A keyboard shortcut, independent of AppKit so it can live in settings and be unit-tested.
public struct KeyShortcut: Equatable, Hashable, Codable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Codable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    public let key: String
    public let modifiers: Modifiers

    public init(key: String, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Menu-style text such as "⇧⌘4" (macOS order: ⌃ ⌥ ⇧ ⌘, then the key).
    public var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + key.uppercased()
    }

    /// A system-wide hotkey must include ⌘, ⌥ or ⌃, otherwise it would hijack normal typing.
    public var isUsableAsGlobalHotkey: Bool {
        !modifiers.isDisjoint(with: [.command, .option, .control])
    }
}

/// Every capture entry point in the menu (requirements §3.1, items 1–9), in menu order.
public enum CaptureMode: String, CaseIterable, Codable, Sendable {
    case allInOne
    case area
    case previousArea
    case fullscreen
    case window
    case scrolling
    case selfTimer
    case ocr
    case recordScreen

    public var defaultShortcut: KeyShortcut? {
        switch self {
        case .allInOne: KeyShortcut(key: "5", modifiers: [.command, .shift])
        case .area: KeyShortcut(key: "4", modifiers: [.command, .shift])
        case .fullscreen: KeyShortcut(key: "3", modifiers: [.command, .shift])
        case .previousArea, .window, .scrolling, .selfTimer, .ocr, .recordScreen: nil
        }
    }
}
