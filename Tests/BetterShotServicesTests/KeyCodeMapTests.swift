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
