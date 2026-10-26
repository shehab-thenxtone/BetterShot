import BetterShotCore

/// Menu labels, SF Symbols and shortcuts. Kept apart from `AppCommand` so the command model stays UI-free.
struct CommandPresentation {
    let title: String
    let symbolName: String?
    let shortcut: KeyShortcut?
}

extension AppCommand {
    /// `hotkeys` supplies the user's current capture shortcuts so the menu shows what's actually bound.
    func presentation(hotkeys: HotkeyBindings) -> CommandPresentation {
        switch self {
        case .capture(let mode):
            CommandPresentation(title: mode.title, symbolName: mode.symbolName, shortcut: hotkeys.shortcut(for: mode))
        case .toggleHideDesktopIcons:
            CommandPresentation(title: "Hide Desktop Icons", symbolName: "eye.slash", shortcut: nil)
        case .openFile:
            CommandPresentation(title: "Open…", symbolName: "folder", shortcut: nil)
        case .pinToScreen:
            CommandPresentation(title: "Pin to the Screen…", symbolName: "pin", shortcut: nil)
        case .restoreRecentlyClosed:
            CommandPresentation(
                title: "Restore Recently Closed File",
                symbolName: "arrow.uturn.backward",
                shortcut: KeyShortcut(key: "z", modifiers: [.command])
            )
        case .about:
            CommandPresentation(title: "About BetterShot…", symbolName: nil, shortcut: nil)
        case .checkForUpdates:
            CommandPresentation(title: "Check for Updates…", symbolName: nil, shortcut: nil)
        case .preferences:
            CommandPresentation(title: "Preferences…", symbolName: nil, shortcut: KeyShortcut(key: ",", modifiers: [.command]))
        case .quit:
            CommandPresentation(title: "Quit", symbolName: nil, shortcut: nil)
        }
    }
}

extension CaptureMode {
    var title: String {
        switch self {
        case .allInOne: "All-In-One"
        case .area: "Capture Area"
        case .previousArea: "Capture Previous Area"
        case .fullscreen: "Capture Fullscreen"
        case .window: "Capture Window"
        case .scrolling: "Scrolling Capture"
        case .selfTimer: "Self-Timer"
        case .ocr: "Capture Text (OCR)"
        case .recordScreen: "Record Screen"
        }
    }

    var symbolName: String {
        switch self {
        case .allInOne: "1.circle"
        case .area: "rectangle.dashed"
        case .previousArea: "arrow.counterclockwise.circle"
        case .fullscreen: "display"
        case .window: "macwindow"
        case .scrolling: "arrow.down.to.line"
        case .selfTimer: "timer"
        case .ocr: "textformat"
        case .recordScreen: "video"
        }
    }
}
