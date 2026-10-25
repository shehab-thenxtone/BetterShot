import BetterShotCore
import Foundation

/// Persists the last captured area as JSON in `UserDefaults`.
public final class UserDefaultsPreviousAreaStore: PreviousAreaStoring, @unchecked Sendable { // UserDefaults is thread-safe
    private static let key = "previousCaptureArea"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PreviousArea? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(PreviousArea.self, from: data)
    }

    public func save(_ area: PreviousArea) {
        guard let data = try? JSONEncoder().encode(area) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
