import BetterShotCore
import Foundation
import Testing
@testable import BetterShotServices

struct UserDefaultsSettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "BetterShotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func loadsDefaultsWhenNothingSaved() {
        #expect(UserDefaultsSettingsStore(defaults: makeDefaults()).load() == AppSettings())
    }

    @Test func roundTripsSavedSettings() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        let settings = AppSettings(
            popupAutoDismissSeconds: 10,
            defaultStorageTarget: .iCloud,
            opensEditorAfterCapture: true,
            launchesAtLogin: true
        )
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test func loadsDefaultsWhenSavedDataIsCorrupt() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: UserDefaultsSettingsStore.key)
        #expect(UserDefaultsSettingsStore(defaults: defaults).load() == AppSettings())
    }
}
