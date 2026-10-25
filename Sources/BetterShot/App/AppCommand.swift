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

    func perform(_ command: AppCommand) {
        switch command {
        case .about:
            NSApp.orderFrontStandardAboutPanel(nil)
        case .quit:
            NSApp.terminate(nil)
        case .capture, .toggleHideDesktopIcons, .openFile, .pinToScreen,
             .restoreRecentlyClosed, .checkForUpdates, .preferences:
            logger.notice("Not implemented yet: \(String(describing: command), privacy: .public)")
        }
    }
}
