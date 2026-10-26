/// Persists `AppSettings`. Implemented by the UserDefaults-backed store; faked in tests.
public protocol SettingsStoring: Sendable {
    /// Saved settings, or the defaults when nothing valid was saved.
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}
