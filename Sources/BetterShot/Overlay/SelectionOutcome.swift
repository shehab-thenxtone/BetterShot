import AppKit
import BetterShotCore

/// What the crosshair overlay lets the user pick.
enum SelectionMode {
    case area
    case window
    case allInOne
    /// Screen recording: an area, or the whole display with Return. Windows can't be recorded.
    case recording

    var allowsArea: Bool { self != .window }
    var allowsWindow: Bool { self == .window || self == .allInOne }
    /// All-In-One and recording also accept Return to use the whole display.
    var allowsFullscreenShortcut: Bool { self == .allInOne || self == .recording }
}

/// Carries display IDs rather than `NSScreen` so the value is `Sendable`; callers look the screen up.
enum SelectionOutcome: Sendable {
    /// `globalRect` is in AppKit global coordinates (bottom-left origin).
    case area(displayID: CGDirectDisplayID, globalRect: CGRect)
    case window(WindowInfo)
    case fullscreen(displayID: CGDirectDisplayID)
    case cancelled
}
