import BetterShotCore
import BetterShotServices
import OSLog

/// Registers the user's capture shortcuts system-wide and routes each press to the command handler.
@MainActor
final class HotkeyController {
    private let center = GlobalHotkeyCenter()
    private weak var handler: (any AppCommandHandler)?
    private let logger = Logger(subsystem: "com.bettershot.app", category: "hotkeys")

    init(handler: any AppCommandHandler) {
        self.handler = handler
    }

    /// Replaces all registered hotkeys. Returns the shortcuts that couldn't be registered.
    @discardableResult
    func apply(_ bindings: HotkeyBindings) -> [KeyShortcut] {
        let registrations = bindings.activeBindings.map { entry in
            GlobalHotkeyCenter.Binding(shortcut: entry.shortcut) { [weak self] in
                self?.handler?.perform(.capture(entry.mode))
            }
        }
        let failed = center.replaceAll(with: registrations)
        for shortcut in failed {
            logger.warning("Could not register hotkey \(shortcut.displayString, privacy: .public)")
        }
        return failed
    }
}
