import Testing
@testable import BetterShotCore

struct CaptureModeTests {
    @Test func defaultShortcutsMatchSpec() {
        #expect(CaptureMode.allInOne.defaultShortcut == KeyShortcut(key: "5", modifiers: [.command, .shift]))
        #expect(CaptureMode.area.defaultShortcut == KeyShortcut(key: "4", modifiers: [.command, .shift]))
        #expect(CaptureMode.fullscreen.defaultShortcut == KeyShortcut(key: "3", modifiers: [.command, .shift]))
    }

    @Test func modesWithoutShortcutInSpecHaveNone() {
        let unbound: [CaptureMode] = [.previousArea, .window, .scrolling, .selfTimer, .ocr, .recordScreen]
        for mode in unbound {
            #expect(mode.defaultShortcut == nil)
        }
    }

    @Test func menuOrderMatchesReference() {
        #expect(CaptureMode.allCases == [
            .allInOne, .area, .previousArea, .fullscreen, .window,
            .scrolling, .selfTimer, .ocr, .recordScreen,
        ])
    }
}
