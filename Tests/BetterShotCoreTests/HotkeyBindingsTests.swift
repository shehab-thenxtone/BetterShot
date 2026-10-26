import Foundation
import Testing
@testable import BetterShotCore

struct HotkeyBindingsTests {
    private let customShortcut = KeyShortcut(key: "9", modifiers: [.command, .option])

    @Test func defaultsMirrorCaptureModeDefaults() {
        for mode in CaptureMode.allCases {
            #expect(HotkeyBindings.defaults.shortcut(for: mode) == mode.defaultShortcut)
        }
    }

    @Test func settingReturnsNewValueAndLeavesOriginalUntouched() {
        let original = HotkeyBindings.defaults
        let updated = original.setting(customShortcut, for: .window)
        #expect(updated.shortcut(for: .window) == customShortcut)
        #expect(original.shortcut(for: .window) == nil)
    }

    @Test func settingNilClearsTheShortcut() {
        let cleared = HotkeyBindings.defaults.setting(nil, for: .area)
        #expect(cleared.shortcut(for: .area) == nil)
    }

    @Test func conflictFindsAnotherModeUsingTheSameShortcut() {
        let areaShortcut = CaptureMode.area.defaultShortcut!
        #expect(HotkeyBindings.defaults.conflict(for: areaShortcut, excluding: .previousArea) == .area)
    }

    @Test func conflictIgnoresTheModeBeingEdited() {
        let areaShortcut = CaptureMode.area.defaultShortcut!
        #expect(HotkeyBindings.defaults.conflict(for: areaShortcut, excluding: .area) == nil)
    }

    @Test func activeBindingsListsAssignedModesInMenuOrder() {
        let active = HotkeyBindings.defaults.activeBindings
        #expect(active.map(\.mode) == [.allInOne, .area, .fullscreen])
    }

    @Test func roundTripsThroughJSONIncludingClearedModes() throws {
        let original = HotkeyBindings.defaults
            .setting(customShortcut, for: .window)
            .setting(nil, for: .area)
        let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(decoded.shortcut(for: .area) == nil)
    }

    @Test func emptyJSONFallsBackToDefaults() throws {
        #expect(try JSONDecoder().decode(HotkeyBindings.self, from: Data("{}".utf8)) == .defaults)
    }

    @Test func modesMissingFromSavedJSONGetTheirDefault() throws {
        let json = #"{"assignments": {"window": null}}"#
        let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: Data(json.utf8))
        #expect(decoded.shortcut(for: .area) == CaptureMode.area.defaultShortcut)
        #expect(decoded.shortcut(for: .window) == nil)
    }
}
