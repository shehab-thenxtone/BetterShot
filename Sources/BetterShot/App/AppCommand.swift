import AppKit
import BetterShotCore
import OSLog

/// Everything the user can trigger from the menu bar (requirements §3.1).
enum AppCommand: Equatable {
    case capture(CaptureMode)
    case toggleHideDesktopIcons
    case openFile
    case pinToScreen
    case restoreRecentlyClosed
    case about
    case checkForUpdates
    case preferences
    case quit
}

@MainActor
protocol AppCommandHandler: AnyObject {
    func perform(_ command: AppCommand)
}

/// Routes commands to their implementations. Features land here phase by phase;
/// anything not yet built is logged rather than silently ignored.
@MainActor
final class AppCommandRouter: AppCommandHandler {
    private let logger = Logger(subsystem: "com.bettershot.app", category: "commands")
    private let captureCoordinator: CaptureCoordinator
    private let actions: Actions

    /// What the router can't do itself; the composition root supplies each one.
    struct Actions {
        let showPreferences: @MainActor () -> Void
        let pinFromFile: @MainActor () -> Void
        let openFile: @MainActor () -> Void
        let restoreRecentlyClosed: @MainActor () -> Void
        let toggleDesktopIcons: @MainActor () -> Void
        /// Runs after every capture attempt finishes, whether or not it produced an image.
        let afterCapture: @MainActor () -> Void
    }

    init(captureCoordinator: CaptureCoordinator, actions: Actions) {
        self.captureCoordinator = captureCoordinator
        self.actions = actions
    }

    func perform(_ command: AppCommand) {
        switch command {
        case .capture(let mode):
            Task {
                await captureCoordinator.start(mode)
                actions.afterCapture()
            }
        case .preferences:
            actions.showPreferences()
        case .pinToScreen:
            actions.pinFromFile()
        case .openFile:
            actions.openFile()
        case .restoreRecentlyClosed:
            actions.restoreRecentlyClosed()
        case .toggleHideDesktopIcons:
            actions.toggleDesktopIcons()
        case .about:
            NSApp.orderFrontStandardAboutPanel(nil)
        case .quit:
            NSApp.terminate(nil)
        case .checkForUpdates:
            logger.notice("Not implemented yet: \(String(describing: command), privacy: .public)")
        }
    }
}
