import Foundation
import Testing
@testable import BetterShotCore

struct AppSettingsTests {
    @Test func defaultsMatchSpec() {
        let settings = AppSettings()
        #expect(settings.defaultStorageTarget == .local)
        #expect(settings.gifExportMode == .auto)
        #expect(settings.opensEditorAfterCapture == false)
        #expect(settings.filenameTemplate == .default)
    }

    @Test func popupTimeoutIsClampedToSaneRange() {
        #expect(AppSettings(popupAutoDismissSeconds: 0).popupAutoDismissSeconds == 2)
        #expect(AppSettings(popupAutoDismissSeconds: 999).popupAutoDismissSeconds == 30)
        #expect(AppSettings(popupAutoDismissSeconds: 8).popupAutoDismissSeconds == 8)
    }

    @Test func roundTripsThroughJSON() throws {
        let original = AppSettings(
            defaultStorageTarget: .googleDrive,
            gifExportMode: .manual(GIFExportSettings(framesPerSecond: 20, colorDepth: .high, isDitheringEnabled: false, scale: .half)),
            opensEditorAfterCapture: true
        )
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func decodingClampsOutOfRangeValues() throws {
        let json = #"{"popupAutoDismissSeconds": 500}"#.data(using: .utf8)!
        #expect(try JSONDecoder().decode(AppSettings.self, from: json).popupAutoDismissSeconds == 30)
    }

    @Test func hotkeyAndLoginDefaults() {
        let settings = AppSettings()
        #expect(settings.hotkeys == .defaults)
        #expect(settings.launchesAtLogin == false)
    }

    @Test func hotkeysAndLaunchAtLoginRoundTripThroughJSON() throws {
        let original = AppSettings(
            hotkeys: HotkeyBindings.defaults.setting(KeyShortcut(key: "9", modifiers: [.command, .option]), for: .window),
            launchesAtLogin: true
        )
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func updatingChangesOnlyTheGivenFields() {
        let original = AppSettings(defaultStorageTarget: .oneDrive, opensEditorAfterCapture: true)
        let updated = original.updating(popupAutoDismissSeconds: 12, launchesAtLogin: true)
        #expect(updated.popupAutoDismissSeconds == 12)
        #expect(updated.launchesAtLogin)
        #expect(updated.defaultStorageTarget == .oneDrive)
        #expect(updated.opensEditorAfterCapture)
        #expect(original.launchesAtLogin == false)
    }

    @Test func updatingStillClampsValues() {
        #expect(AppSettings().updating(popupAutoDismissSeconds: 1000).popupAutoDismissSeconds == 30)
    }

    @Test func missingKeysFallBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(decoded == AppSettings())
    }
}
