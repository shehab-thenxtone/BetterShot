import BetterShotCore
import Foundation

/// Stores `AppSettings` as one JSON blob in `UserDefaults`. Unreadable data falls back to defaults
/// instead of failing, so a corrupt value can never stop the app launching.
public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable { // UserDefaults is thread-safe
    static let key = "appSettings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: Self.key),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
