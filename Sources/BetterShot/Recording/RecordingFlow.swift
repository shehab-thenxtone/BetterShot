import AppKit
import BetterShotCore
import BetterShotServices

/// What happens to a finished (or opened) recording: show the result card, then Save MP4, Export GIF… or Copy.
@MainActor
final class RecordingFlow {
    private let folderStore: any SaveFolderStoring
    private let settings: SettingsModel
    private let toast: ToastController
    private let card = RecordingResultController()
    private var gifWindows: [GIFExportWindowController] = []

    init(folderStore: any SaveFolderStoring, settings: SettingsModel, toast: ToastController) {
        self.folderStore = folderStore
        self.settings = settings
        self.toast = toast
    }

    func present(_ result: RecordingResult) {
        present(url: result.url)
    }

    /// "Open…" on a video file: it gets the same card, so a past recording can still be saved or turned into a GIF.
    func open(url: URL) {
        present(url: url)
    }

    // MARK: Private

    private func present(url: URL) {
        Task { [weak self] in
            guard let self else { return }
            guard let info = try? await VideoInfo.load(from: url) else {
                CaptureAlerts.presentInfo(title: "Couldn't open recording", message: "\(url.lastPathComponent) isn't a readable video.", style: .warning)
                return
            }
            card.show(
                url: url,
                info: info,
                actions: RecordingResultActions(
                    save: { [weak self] in self?.saveMP4(url) },
                    exportGIF: { [weak self] in self?.exportGIF(url, info) },
                    copy: { [weak self] in self?.copy(url) },
                    close: { [weak self] in self?.card.dismiss() }
                )
            )
        }
    }

    private func saveMP4(_ url: URL) {
        do {
            let saved = try LocalFileSaver(folderStore: folderStore).copy(url, fileExtension: "mp4")
            toast.show("Saved \(saved.lastPathComponent)", symbol: "checkmark.circle")
            card.dismiss()
        } catch {
            CaptureAlerts.present(error)
        }
    }

    private func copy(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL]) // a file reference: paste into Finder, Slack, Mail…
        toast.show("Copied recording", symbol: "doc.on.clipboard")
    }

    private func exportGIF(_ url: URL, _ info: VideoInfo) {
        let window = GIFExportWindowController(video: url, info: info, settings: settings, folderStore: folderStore, toast: toast)
        window.onClose = { [weak self] closed in self?.gifWindows.removeAll { $0 === closed } }
        gifWindows.append(window)
        window.show()
    }
}
