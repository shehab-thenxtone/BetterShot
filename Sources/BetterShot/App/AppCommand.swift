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
    private let showPreferences: @MainActor () -> Void
    private let pinFromFile: @MainActor () -> Void

    init(
        captureCoordinator: CaptureCoordinator,
        showPreferences: @escaping @MainActor () -> Void,
        pinFromFile: @escaping @MainActor () -> Void
    ) {
        self.captureCoordinator = captureCoordinator
        self.showPreferences = showPreferences
        self.pinFromFile = pinFromFile
    }

    func perform(_ command: AppCommand) {
        switch command {
        case .capture(let mode):
            Task { await captureCoordinator.start(mode) }
        case .preferences:
            showPreferences()
        case .pinToScreen:
            pinFromFile()
        case .about:
            NSApp.orderFrontStandardAboutPanel(nil)
        case .quit:
            NSApp.terminate(nil)
        case .toggleHideDesktopIcons, .openFile,
             .restoreRecentlyClosed, .checkForUpdates:
            logger.notice("Not implemented yet: \(String(describing: command), privacy: .public)")
        }
    }
}
