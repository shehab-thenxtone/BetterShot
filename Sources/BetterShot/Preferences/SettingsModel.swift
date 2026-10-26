import BetterShotCore
import Observation

/// The live, observable `AppSettings`. Every change is persisted immediately and reported to `onChange`
/// so the app can re-register hotkeys, relabel the menu and update the login item.
@MainActor
@Observable
final class SettingsModel {
    private(set) var settings: AppSettings

    @ObservationIgnored private let store: any SettingsStoring
    @ObservationIgnored var onChange: ((_ old: AppSettings, _ new: AppSettings) -> Void)?

    init(store: any SettingsStoring) {
        self.store = store
        settings = store.load()
    }

    func update(_ transform: (AppSettings) -> AppSettings) {
        let old = settings
        let new = transform(old)
        guard new != old else { return }
        settings = new
        store.save(new)
        onChange?(old, new)
    }
}
