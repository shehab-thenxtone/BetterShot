import BetterShotCore
import Testing
@testable import BetterShotServices

struct KeyCodeMapTests {
    @Test func mapsDigitsUsedByTheDefaultShortcuts() {
        #expect(KeyCodeMap.keyCode(for: "3") == 20)
        #expect(KeyCodeMap.keyCode(for: "4") == 21)
        #expect(KeyCodeMap.keyCode(for: "5") == 23)
    }

    @Test func mapsLettersCaseInsensitively() {
        #expect(KeyCodeMap.keyCode(for: "a") == 0)
        #expect(KeyCodeMap.keyCode(for: "A") == 0)
        #expect(KeyCodeMap.keyCode(for: "z") == 6)
    }

    @Test func reverseLookupReturnsTheUnshiftedKey() {
        #expect(KeyCodeMap.key(forKeyCode: 21) == "4")
        #expect(KeyCodeMap.key(forKeyCode: 0) == "a")
        #expect(KeyCodeMap.key(forKeyCode: 53) == nil) // Escape
    }

    @Test func everyKnownKeyRoundTrips() {
        for key in ["a", "z", "0", "9", "[", "`", "/"] {
            let code = KeyCodeMap.keyCode(for: key)!
            #expect(KeyCodeMap.key(forKeyCode: code) == key)
        }
    }

    @Test func rejectsKeysItDoesNotKnow() {
        #expect(KeyCodeMap.keyCode(for: "é") == nil)
        #expect(KeyCodeMap.keyCode(for: "") == nil)
        #expect(KeyCodeMap.keyCode(for: "ab") == nil)
    }

    @Test func translatesModifiersToCarbonFlags() {
        #expect(KeyCodeMap.carbonModifiers(for: [.command, .shift]) == 256 | 512)
        #expect(KeyCodeMap.carbonModifiers(for: [.option, .control]) == 2048 | 4096)
        #expect(KeyCodeMap.carbonModifiers(for: []) == 0)
    }
}
