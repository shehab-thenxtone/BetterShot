import Testing
@testable import BetterShotCore

struct KeyShortcutTests {
    @Test func displayStringUsesMacModifierOrder() {
        #expect(KeyShortcut(key: "4", modifiers: [.command, .shift]).displayString == "⇧⌘4")
        #expect(KeyShortcut(key: "a", modifiers: [.command, .shift, .option, .control]).displayString == "⌃⌥⇧⌘A")
        #expect(KeyShortcut(key: ",", modifiers: [.command]).displayString == "⌘,")
    }

    @Test func globalHotkeysNeedACommandOptionOrControlModifier() {
        #expect(KeyShortcut(key: "4", modifiers: [.command]).isUsableAsGlobalHotkey)
        #expect(KeyShortcut(key: "4", modifiers: [.option]).isUsableAsGlobalHotkey)
        #expect(KeyShortcut(key: "4", modifiers: [.control, .shift]).isUsableAsGlobalHotkey)
        #expect(!KeyShortcut(key: "4", modifiers: [.shift]).isUsableAsGlobalHotkey)
        #expect(!KeyShortcut(key: "4", modifiers: []).isUsableAsGlobalHotkey)
    }
}
