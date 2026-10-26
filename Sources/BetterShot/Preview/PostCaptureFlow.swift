import AppKit
import BetterShotCore
import BetterShotServices
import OSLog

/// What happens after a capture finishes: show the preview popup and carry out its Copy / Save / Upload actions
/// without ever opening the editor (requirements §3.2, "fast capture" workflow).
@MainActor
final class PostCaptureFlow {
    private let folderStore: any SaveFolderStoring
    private let settings: () -> AppSettings
    private let panel = PreviewPanelController()
    private let logger = Logger(subsystem: "com.bettershot.app", category: "post-capture")

    /// `settings` is read per capture so Preferences changes (phase 5) apply immediately.
    init(folderStore: any SaveFolderStoring, settings: @escaping () -> AppSettings) {
        self.folderStore = folderStore
        self.settings = settings
    }

    /// Opens the annotation editor for an image. Set after construction because the editor hands results back here.
    var openEditor: (@MainActor (CGImage) -> Void)?

    /// Shows the preview popup, or jumps straight into the editor when "open editor automatically" is on.
    /// The editor passes `opensEditorIfConfigured: false` when finishing so it doesn't reopen itself.
    func present(_ result: CaptureResult, opensEditorIfConfigured: Bool = true) {
        let image = result.image
        if opensEditorIfConfigured, settings().opensEditorAfterCapture, let openEditor {
            openEditor(image)
            return
        }
        panel.show(
            image: image,
            isPinAvailable: false, // phase 8
            autoDismissAfter: settings().popupAutoDismissSeconds,
            actions: PreviewActions(
                copy: { [weak self] in self?.copy(image) },
                save: { [weak self] in self?.save(image) },
                pin: {},
                upload: { [weak self] in self?.upload(image) },
                edit: { [weak self] in self?.edit(image) }
            )
        )
    }

    // MARK: Actions

    private func edit(_ image: CGImage) {
        panel.dismiss()
        openEditor?(image)
    }

    private func copy(_ image: CGImage) {
        ImageClipboard.copy(image)
        panel.dismiss()
    }

    private func save(_ image: CGImage) {
        let saver = LocalImageSaver(folderStore: folderStore, template: settings().filenameTemplate)
        do {
            let url = try saver.savePNG(image)
            logger.notice("Saved \(url.lastPathComponent, privacy: .public)")
            panel.dismiss()
        } catch {
            CaptureAlerts.present(error)
        }
    }

    /// The cloud icon follows the default storage target; only Local Storage exists until phase 13.
    private func upload(_ image: CGImage) {
        switch settings().defaultStorageTarget {
        case .local:
            save(image)
        case .googleDrive, .oneDrive, .iCloud:
            CaptureAlerts.presentInfo(
                title: "Destination not linked",
                message: "Linking cloud accounts isn't available yet. Use Save to store the image locally."
            )
        }
    }
}
