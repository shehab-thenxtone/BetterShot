/// Proposes easy-to-press shortcuts for capture modes. Which combinations are actually free (not used by another
/// mode, the system or another app) is the caller's to say, so this stays pure.
///
/// "Easy" means few modifiers and a letter you can remember: ⌃⌥ plus the mode's own letter comes first (⌃⌥A for
/// Capture Area), then ⌃⌥ with other letters and digits, then heavier chords. ⌃⌥ is rarely used by apps and
/// macOS, so it is usually free.
public enum ShortcutSuggester {
    /// From lightest to heaviest; a chord with ⌘ comes late because apps use ⌘-combinations the most.
    private static let modifierSets: [KeyShortcut.Modifiers] = [
        [.control, .option],
        [.control, .option, .shift],
        [.control, .command],
        [.command, .option],
    ]

    private static let fallbackKeys = "abcdefghijklmnopqrstuvwxyz123456789".map(String.init)

    /// The letter that reminds you of the mode.
    public static func mnemonic(for mode: CaptureMode) -> String {
        switch mode {
        case .allInOne: "i"
        case .area: "a"
        case .previousArea: "p"
        case .fullscreen: "f"
        case .window: "w"
        case .scrolling: "s"
        case .selfTimer: "t"
        case .ocr: "o"
        case .recordScreen: "r"
        }
    }

    /// Every candidate for `mode`, easiest first.
    public static func candidates(for mode: CaptureMode) -> [KeyShortcut] {
        let first = mnemonic(for: mode)
        let keys = [first] + fallbackKeys.filter { $0 != first }
        return modifierSets.flatMap { modifiers in keys.map { KeyShortcut(key: $0, modifiers: modifiers) } }
    }

    /// The easiest candidate that `isFree` accepts. `current` (the mode's present shortcut) is skipped, so asking
    /// again moves on to the next suggestion instead of repeating itself.
    public static func suggestion(
        for mode: CaptureMode,
        excluding current: KeyShortcut? = nil,
        isFree: (KeyShortcut) -> Bool
    ) -> KeyShortcut? {
        candidates(for: mode).first { $0 != current && isFree($0) }
    }
}
