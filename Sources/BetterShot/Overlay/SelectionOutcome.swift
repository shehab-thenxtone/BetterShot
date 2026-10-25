import AppKit
import BetterShotCore

/// What the crosshair overlay lets the user pick.
enum SelectionMode {
    case area
    case window
    case allInOne

    var allowsArea: Bool { self != .window }
    var allowsWindow: Bool { self != .area }
    /// All-In-One also accepts Return to capture the whole display.
    var allowsFullscreenShortcut: Bool { self == .allInOne }
}

/// Carries display IDs rather than `NSScreen` so the value is `Sendable`; callers look the screen up.
enum SelectionOutcome: Sendable {
    /// `globalRect` is in AppKit global coordinates (bottom-left origin).
    case area(displayID: CGDirectDisplayID, globalRect: CGRect)
    case window(WindowInfo)
    case fullscreen(displayID: CGDirectDisplayID)
    case cancelled
}
