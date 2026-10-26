import BetterShotAnnotations
import Foundation
import Testing
@testable import BetterShotServices

struct UserDefaultsToolStylesStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "BetterShotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func loadsDefaultsWhenNothingSaved() {
        #expect(UserDefaultsToolStylesStore(defaults: makeDefaults()).load() == .defaults)
    }

    @Test func roundTripsSavedStyles() {
        let store = UserDefaultsToolStylesStore(defaults: makeDefaults())
        let styles = ToolStyles.defaults
            .setting(AnnotationStyle().updating(color: .mint, lineWeight: .thick), for: .arrow)
            .setting(AnnotationStyle().updating(color: .azure), for: .rectangle)
        store.save(styles)
        #expect(store.load() == styles)
    }

    @Test func loadsDefaultsWhenSavedDataIsCorrupt() {
        let defaults = makeDefaults()
        defaults.set(Data("nope".utf8), forKey: UserDefaultsToolStylesStore.key)
        #expect(UserDefaultsToolStylesStore(defaults: defaults).load() == .defaults)
    }
}
