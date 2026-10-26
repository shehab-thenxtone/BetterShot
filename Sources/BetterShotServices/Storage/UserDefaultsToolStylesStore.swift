import BetterShotAnnotations
import Foundation

/// Persists the editor's per-tool colours and weights so they survive between sessions (requirements §3.3).
/// Unreadable data falls back to the defaults.
public final class UserDefaultsToolStylesStore: @unchecked Sendable { // UserDefaults is thread-safe
    static let key = "toolStyles"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ToolStyles {
        guard
            let data = defaults.data(forKey: Self.key),
            let styles = try? JSONDecoder().decode(ToolStyles.self, from: data)
        else { return .defaults }
        return styles
    }

    public func save(_ styles: ToolStyles) {
        guard let data = try? JSONEncoder().encode(styles) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
