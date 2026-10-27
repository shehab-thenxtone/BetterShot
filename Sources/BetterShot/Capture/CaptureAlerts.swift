import AppKit
import BetterShotCore

@MainActor
enum CaptureAlerts {
    private static let screenRecordingSettingsURL =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

    static func present(_ error: CaptureError) {
        if error == .permissionDenied {
            presentPermissionDenied()
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't capture"
        alert.informativeText = error.errorDescription ?? "Unknown error."
        alert.runModal()
    }

    static func present(_ error: SaveError) {
        presentInfo(title: "Couldn't save", message: error.errorDescription ?? "Unknown error.", style: .warning)
    }

    static func presentInfo(title: String, message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    /// Scrolling Capture scrolls other apps by posting events, which macOS only allows with Accessibility access.
    static func presentAccessibilityNeeded() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Accessibility permission needed"
        alert.informativeText = "Scrolling Capture scrolls other apps for you, which macOS only allows with Accessibility access. Enable BetterShot under Privacy & Security → Accessibility, then try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func presentPermissionDenied() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screen Recording permission needed"
        alert.informativeText = "Enable BetterShot under Privacy & Security → Screen Recording, then reopen BetterShot."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: screenRecordingSettingsURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
