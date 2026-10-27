import BetterShotCore
import Testing
@testable import BetterShotServices

struct SystemShortcutsTests {
    private let commandShift: KeyShortcut.Modifiers = [.command, .shift]

    private func entry(_ key: String, _ modifiers: KeyShortcut.Modifiers, enabled: Bool = true) -> SystemShortcuts.Entry {
        SystemShortcuts.Entry(
            keyCode: KeyCodeMap.keyCode(for: key)!, modifiers: KeyCodeMap.carbonModifiers(for: modifiers), isEnabled: enabled
        )
    }

    @Test func flagsAnEnabledSystemShortcutAndNamesTheScreenshotOnes() {
        let conflict = SystemShortcuts.conflict(for: KeyShortcut(key: "4", modifiers: commandShift), among: [entry("4", commandShift)])

        #expect(conflict?.purpose == "the macOS screenshot of a selected area")
    }

    @Test func describesOtherSystemShortcutsGenerically() {
        let conflict = SystemShortcuts.conflict(for: KeyShortcut(key: "d", modifiers: [.command, .option]), among: [entry("d", [.command, .option])])

        #expect(conflict?.purpose == "a macOS system shortcut")
    }

    @Test func ignoresShortcutsTheUserSwitchedOffInSystemSettings() {
        let entries = [entry("4", commandShift, enabled: false)]

        #expect(SystemShortcuts.conflict(for: KeyShortcut(key: "4", modifiers: commandShift), among: entries) == nil)
    }

    @Test func requiresTheSameKeyAndTheSameModifiers() {
        let entries = [entry("4", commandShift)]

        #expect(SystemShortcuts.conflict(for: KeyShortcut(key: "4", modifiers: [.command]), among: entries) == nil)
        #expect(SystemShortcuts.conflict(for: KeyShortcut(key: "5", modifiers: commandShift), among: entries) == nil)
        #expect(SystemShortcuts.conflict(for: KeyShortcut(key: "4", modifiers: [.control, .option]), among: entries) == nil)
    }

    @Test func everyEnabledShortcutInTheRealSystemListIsReportedAsAConflict() {
        // The list differs per Mac, so check the decoding rather than particular shortcuts: each enabled entry that
        // is a plain letter/digit key with ⌘⇧⌥⌃ modifiers must come back as a conflict.
        let entries = SystemShortcuts.currentEntries()
        #expect(!entries.isEmpty)

        let knownModifierBits: UInt32 = 0x1B00 // ⌘ ⇧ ⌥ ⌃ in Carbon's mask
        for entry in entries where entry.isEnabled && entry.modifiers & ~knownModifierBits == 0 {
            guard let key = KeyCodeMap.key(forKeyCode: entry.keyCode) else { continue }
            var modifiers: KeyShortcut.Modifiers = []
            if entry.modifiers & (1 << 8) != 0 { modifiers.insert(.command) }
            if entry.modifiers & (1 << 9) != 0 { modifiers.insert(.shift) }
            if entry.modifiers & (1 << 11) != 0 { modifiers.insert(.option) }
            if entry.modifiers & (1 << 12) != 0 { modifiers.insert(.control) }

            #expect(SystemShortcuts.conflict(for: KeyShortcut(key: key, modifiers: modifiers)) != nil, "key \(key) mods \(entry.modifiers)")
        }
    }
}

struct GlobalHotkeyAvailabilityTests {
    @MainActor
    @Test func aFreeCombinationCanBeRegisteredAndIsReleasedAgain() {
        let shortcut = KeyShortcut(key: "j", modifiers: [.control, .option, .shift, .command])

        #expect(GlobalHotkeyCenter.isAvailable(shortcut))
        #expect(GlobalHotkeyCenter.isAvailable(shortcut)) // released after the first probe, so still free
    }

    @MainActor
    @Test func aCombinationAlreadyRegisteredIsNotAvailable() {
        let center = GlobalHotkeyCenter()
        let shortcut = KeyShortcut(key: "k", modifiers: [.control, .option, .shift, .command])
        center.replaceAll(with: [.init(shortcut: shortcut, handler: {})])
        defer { center.unregisterAll() }

        #expect(!GlobalHotkeyCenter.isAvailable(shortcut))
    }

    @Test func anUnknownKeyIsNotAvailable() {
        #expect(!GlobalHotkeyCenter.isAvailable(KeyShortcut(key: "€", modifiers: [.command])))
    }
}
