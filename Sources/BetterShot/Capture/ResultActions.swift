import AppKit
import BetterShotCore
import BetterShotServices
import OSLog

/// What every result surface (preview popup, result bar, pinned image) can do with an image, in one place so
/// they can't drift apart: copy, silent save, and the cloud button.
@MainActor
final class ResultActions {
    private let folderStore: any SaveFolderStoring
    private let settings: () -> AppSettings
    private let recentlyClosed: RecentlyClosedStore
    private let logger = Logger(subsystem: "com.bettershot.app", category: "result-actions")

    /// `settings` is read per action so Preferences changes apply immediately.
    init(folderStore: any SaveFolderStoring, settings: @escaping () -> AppSettings, recentlyClosed: RecentlyClosedStore) {
        self.folderStore = folderStore
        self.settings = settings
        self.recentlyClosed = recentlyClosed
    }

    /// Remembers an image the user closed without keeping, for "Restore Recently Closed File". Replaces the previous one.
    func recordClosed(_ image: CGImage) {
        recentlyClosed.save(image)
    }

    func copy(_ image: CGImage) {
        ImageClipboard.copy(image)
    }

    /// Saves a PNG to the remembered folder with no dialog. On failure the user is told and `false` is returned.
    @discardableResult
    func save(_ image: CGImage) -> Bool {
        let saver = LocalImageSaver(folderStore: folderStore, template: settings().filenameTemplate)
        do {
            let url = try saver.savePNG(image)
            logger.notice("Saved \(url.lastPathComponent, privacy: .public)")
            return true
        } catch {
            CaptureAlerts.present(error)
            return false
        }
    }

    /// The cloud icon follows the default storage target; only Local Storage exists until phase 13.
    @discardableResult
    func upload(_ image: CGImage) -> Bool {
        switch settings().defaultStorageTarget {
        case .local:
            return save(image)
        case .googleDrive, .oneDrive, .iCloud:
            CaptureAlerts.presentInfo(
                title: "Destination not linked",
                message: "Linking cloud accounts isn't available yet. Use Save to store the image locally."
            )
            return false
        }
    }
}
