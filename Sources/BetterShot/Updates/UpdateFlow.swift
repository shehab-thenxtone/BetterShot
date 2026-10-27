import AppKit
import BetterShotCore
import BetterShotServices
import OSLog

/// "Check for Updates…" from the menu: asks the release feed and tells the user the result.
@MainActor
final class UpdateFlow {
    private let logger = Logger(subsystem: "com.bettershot.app", category: "updates")
    private var isChecking = false

    func run() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            guard let feedURL = UpdateChecker.feedURL() else { throw UpdateCheckError.notConfigured }
            guard let current = UpdateChecker.currentVersion() else { throw UpdateCheckError.unknownCurrentVersion }
            switch try await UpdateChecker(feedURL: feedURL, currentVersion: current).check() {
            case .upToDate(let version):
                CaptureAlerts.presentInfo(title: "You're up to date", message: "BetterShot \(version) is the latest version.")
            case .available(let update):
                offer(update, current: current)
            }
        } catch {
            logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            CaptureAlerts.presentInfo(title: "Couldn't check for updates", message: error.localizedDescription, style: .warning)
        }
    }

    private func offer(_ update: AvailableUpdate, current: AppVersion) {
        let alert = NSAlert()
        alert.messageText = "BetterShot \(update.version) is available"
        alert.informativeText = "You have \(current). Open the download page to get the new version."
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(update.pageURL) }
    }
}
