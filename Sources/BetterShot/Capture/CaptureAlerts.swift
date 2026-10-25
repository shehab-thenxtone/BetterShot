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
