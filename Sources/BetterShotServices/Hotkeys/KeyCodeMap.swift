import BetterShotCore

/// Translates `KeyShortcut` into Carbon hotkey codes. Covers the ANSI letter, digit and punctuation keys,
/// which is what the shortcut recorder accepts; anything else is rejected rather than silently misbound.
public enum KeyCodeMap {
    // Carbon `kVK_ANSI_*` virtual key codes.
    private static let codes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50,
    ]

    private static let keysByCode: [UInt32: String] = Dictionary(uniqueKeysWithValues: codes.map { ($1, $0) })

    public static func keyCode(for key: String) -> UInt32? {
        codes[key.lowercased()]
    }

    /// The unshifted key for a physical key code, so ⇧4 records as "4" rather than "$".
    public static func key(forKeyCode keyCode: UInt32) -> String? {
        keysByCode[keyCode]
    }

    /// Carbon modifier mask (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
    public static func carbonModifiers(for modifiers: KeyShortcut.Modifiers) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= 1 << 8 }
        if modifiers.contains(.shift) { flags |= 1 << 9 }
        if modifiers.contains(.option) { flags |= 1 << 11 }
        if modifiers.contains(.control) { flags |= 1 << 12 }
        return flags
    }
}
