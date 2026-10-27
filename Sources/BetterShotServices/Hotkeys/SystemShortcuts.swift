import BetterShotCore
import Carbon.HIToolbox
import Foundation

/// A macOS shortcut that would take a key combination before (or instead of) BetterShot.
public struct SystemShortcutConflict: Equatable, Sendable {
    /// What the system uses it for, e.g. "the macOS screenshot of a selected area".
    public let purpose: String
}

/// The key combinations macOS reserves for itself (the "Keyboard Shortcuts" panes of System Settings: screenshots,
/// Mission Control, Spotlight, input sources and so on), read from the system rather than hard-coded, so a
/// shortcut the user has switched off there doesn't count.
public enum SystemShortcuts {
    public struct Entry: Equatable, Sendable {
        public let keyCode: UInt32
        /// Carbon modifier mask, as `KeyCodeMap.carbonModifiers(for:)` produces.
        public let modifiers: UInt32
        public let isEnabled: Bool

        public init(keyCode: UInt32, modifiers: UInt32, isEnabled: Bool) {
            self.keyCode = keyCode
            self.modifiers = modifiers
            self.isEnabled = isEnabled
        }
    }

    /// Why a combination is reserved, for the ones people actually collide with. Anything else is described generically.
    private static let knownPurposes: [KeyShortcut: String] = [
        KeyShortcut(key: "3", modifiers: [.command, .shift]): "the macOS screenshot of the whole screen",
        KeyShortcut(key: "3", modifiers: [.command, .shift, .control]): "the macOS screenshot of the whole screen (copied)",
        KeyShortcut(key: "4", modifiers: [.command, .shift]): "the macOS screenshot of a selected area",
        KeyShortcut(key: "4", modifiers: [.command, .shift, .control]): "the macOS screenshot of a selected area (copied)",
        KeyShortcut(key: "5", modifiers: [.command, .shift]): "the macOS screenshot and recording tools",
    ]

    public static func conflict(for shortcut: KeyShortcut) -> SystemShortcutConflict? {
        conflict(for: shortcut, among: currentEntries())
    }

    /// The matching rule, separate from reading the system so it can be tested with made-up entries.
    public static func conflict(for shortcut: KeyShortcut, among entries: [Entry]) -> SystemShortcutConflict? {
        guard let keyCode = KeyCodeMap.keyCode(for: shortcut.key) else { return nil }
        let modifiers = KeyCodeMap.carbonModifiers(for: shortcut.modifiers)
        guard entries.contains(where: { $0.isEnabled && $0.keyCode == keyCode && $0.modifiers == modifiers }) else { return nil }
        return SystemShortcutConflict(purpose: knownPurposes[shortcut] ?? "a macOS system shortcut")
    }

    /// Every symbolic hotkey the system currently defines, enabled or not.
    static func currentEntries() -> [Entry] {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let list = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard
                let keyCode = item[kHISymbolicHotKeyCode as String] as? Int,
                let modifiers = item[kHISymbolicHotKeyModifiers as String] as? Int
            else { return nil }
            let isEnabled = item[kHISymbolicHotKeyEnabled as String] as? Bool ?? true
            return Entry(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers), isEnabled: isEnabled)
        }
    }
}
