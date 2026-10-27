import Testing
@testable import BetterShotCore

struct ShortcutSuggesterTests {
    @Test func theFirstChoiceIsControlOptionPlusTheModesOwnLetter() {
        let suggestion = ShortcutSuggester.suggestion(for: .area, isFree: { _ in true })

        #expect(suggestion == KeyShortcut(key: "a", modifiers: [.control, .option]))
        #expect(suggestion?.displayString == "⌃⌥A")
    }

    @Test func everyModeHasItsOwnLetter() {
        let letters = CaptureMode.allCases.map(ShortcutSuggester.mnemonic(for:))

        #expect(Set(letters).count == CaptureMode.allCases.count)
    }

    @Test func skipsCombinationsThatAreNotFree() {
        let taken: Set<KeyShortcut> = [KeyShortcut(key: "a", modifiers: [.control, .option])]

        let suggestion = ShortcutSuggester.suggestion(for: .area, isFree: { !taken.contains($0) })

        // Still the light chord, with the next key, rather than jumping to a heavier chord.
        #expect(suggestion?.modifiers == [.control, .option])
        #expect(suggestion?.key == "b")
    }

    @Test func movesToAHeavierChordOnlyWhenTheLightOnesAreAllTaken() {
        let suggestion = ShortcutSuggester.suggestion(for: .window, isFree: { !$0.modifiers.isSubset(of: [.control, .option]) })

        #expect(suggestion == KeyShortcut(key: "w", modifiers: [.control, .option, .shift]))
    }

    @Test func neverRepeatsTheCurrentShortcut() {
        let current = KeyShortcut(key: "a", modifiers: [.control, .option])

        let suggestion = ShortcutSuggester.suggestion(for: .area, excluding: current, isFree: { _ in true })

        #expect(suggestion != current)
        #expect(suggestion?.modifiers == [.control, .option])
    }

    @Test func returnsNilWhenNothingIsFree() {
        #expect(ShortcutSuggester.suggestion(for: .ocr, isFree: { _ in false }) == nil)
    }

    @Test func everyCandidateIsUsableAsAGlobalHotkeyAndUnique() {
        for mode in CaptureMode.allCases {
            let candidates = ShortcutSuggester.candidates(for: mode)

            #expect(candidates.allSatisfy { $0.isUsableAsGlobalHotkey })
            #expect(Set(candidates).count == candidates.count)
        }
    }
}
