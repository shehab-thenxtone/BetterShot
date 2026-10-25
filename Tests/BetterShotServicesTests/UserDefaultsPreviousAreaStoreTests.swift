import CoreGraphics
import Foundation
import Testing
import BetterShotCore
@testable import BetterShotServices

struct UserDefaultsPreviousAreaStoreTests {
    private func makeStore() -> UserDefaultsPreviousAreaStore {
        let suite = "BetterShotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return UserDefaultsPreviousAreaStore(defaults: defaults)
    }

    @Test func loadsNilWhenNothingSaved() {
        #expect(makeStore().load() == nil)
    }

    @Test func roundTripsSavedArea() {
        let store = makeStore()
        let area = PreviousArea(displayID: 42, rect: CGRect(x: 10, y: 20, width: 300, height: 200))
        store.save(area)
        #expect(store.load() == area)
    }

    @Test func saveOverwritesPreviousValue() {
        let store = makeStore()
        store.save(PreviousArea(displayID: 1, rect: CGRect(x: 0, y: 0, width: 10, height: 10)))
        let latest = PreviousArea(displayID: 2, rect: CGRect(x: 5, y: 5, width: 50, height: 50))
        store.save(latest)
        #expect(store.load() == latest)
    }
}
