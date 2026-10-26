import Foundation

/// The user's shortcut for each capture mode (requirements §3.1: globally registered and user-remappable).
/// A mode with no entry is unbound. Value type: every edit returns a new `HotkeyBindings`.
public struct HotkeyBindings: Equatable, Codable, Sendable {
    public static let defaults = HotkeyBindings(
        assignments: Dictionary(uniqueKeysWithValues: CaptureMode.allCases.compactMap { mode in
            mode.defaultShortcut.map { (mode, $0) }
        })
    )

    private let assignments: [CaptureMode: KeyShortcut]

    private init(assignments: [CaptureMode: KeyShortcut]) {
        self.assignments = assignments
    }

    public func shortcut(for mode: CaptureMode) -> KeyShortcut? {
        assignments[mode]
    }

    /// Returns a copy with `mode` bound to `shortcut`, or unbound when `shortcut` is nil.
    public func setting(_ shortcut: KeyShortcut?, for mode: CaptureMode) -> HotkeyBindings {
        var updated = assignments
        updated[mode] = shortcut
        return HotkeyBindings(assignments: updated)
    }

    /// Another mode already using `shortcut`, ignoring `mode` itself.
    public func conflict(for shortcut: KeyShortcut, excluding mode: CaptureMode) -> CaptureMode? {
        CaptureMode.allCases.first { $0 != mode && assignments[$0] == shortcut }
    }

    /// Bound modes in menu order.
    public var activeBindings: [(mode: CaptureMode, shortcut: KeyShortcut)] {
        CaptureMode.allCases.compactMap { mode in
            assignments[mode].map { (mode, $0) }
        }
    }

    // MARK: Codable
    // Saved as {"assignments": {"<mode>": <shortcut> | null}}. null = deliberately unbound; a mode missing
    // from the file (e.g. added in a later version) keeps its default.

    private enum CodingKeys: String, CodingKey { case assignments }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saved = try container.decodeIfPresent([String: KeyShortcut?].self, forKey: .assignments) ?? [:]

        var resolved: [CaptureMode: KeyShortcut] = [:]
        for mode in CaptureMode.allCases {
            if let entry = saved[mode.rawValue] {
                if let shortcut = entry { resolved[mode] = shortcut }
            } else if let fallback = mode.defaultShortcut {
                resolved[mode] = fallback
            }
        }
        self.init(assignments: resolved)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var saved: [String: KeyShortcut?] = [:]
        for mode in CaptureMode.allCases {
            saved[mode.rawValue] = .some(assignments[mode])
        }
        try container.encode(saved, forKey: .assignments)
    }
}
