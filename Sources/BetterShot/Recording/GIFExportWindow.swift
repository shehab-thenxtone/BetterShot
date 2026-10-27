import AppKit
import BetterShotCore
import BetterShotServices
import Observation
import SwiftUI

@MainActor
@Observable
final class GIFExportModel {
    var isExporting = false
    var progress = 0.0
    var errorMessage: String?
}

/// The "Export GIF…" window: pick Auto or Manual settings, watch the live size estimate, export. The result is
/// saved silently to the remembered folder like other saves. Changes here persist as the default GIF mode.
@MainActor
final class GIFExportWindowController: NSObject, NSWindowDelegate {
    private let video: URL
    private let info: VideoInfo
    private let settings: SettingsModel
    private let folderStore: any SaveFolderStoring
    private let toast: ToastController
    private let model = GIFExportModel()
    private var window: NSWindow?
    private var exportTask: Task<Void, Never>?

    var onClose: (@MainActor (GIFExportWindowController) -> Void)?

    init(video: URL, info: VideoInfo, settings: SettingsModel, folderStore: any SaveFolderStoring, toast: ToastController) {
        self.video = video
        self.info = info
        self.settings = settings
        self.folderStore = folderStore
        self.toast = toast
        super.init()
        window = makeWindow()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Window

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Export GIF"
        window.isReleasedWhenClosed = false
        window.delegate = self
        // A hosting *controller* with preferredContentSize lets the window grow when Manual adds its controls.
        let content = NSHostingController(rootView: GIFExportView(
            model: model,
            settings: settings,
            info: info,
            onExport: { [weak self] in self?.export() },
            onCancel: { [weak self] in self?.cancel() }
        ))
        content.sizingOptions = [.preferredContentSize]
        window.contentViewController = content
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        exportTask?.cancel()
        onClose?(self)
    }

    // MARK: Export

    private func export() {
        guard !model.isExporting else { return }
        model.isExporting = true
        model.progress = 0
        model.errorMessage = nil

        let resolved = settings.settings.gifExportMode.settings(sourceFramesPerSecond: info.framesPerSecond)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("BetterShot-\(UUID().uuidString).gif")
        let video = video
        let folderStore = folderStore

        exportTask = Task { [weak self] in
            do {
                try await GIFExporter().export(
                    video: video, to: temporary, settings: resolved,
                    progress: { value in Task { @MainActor in self?.model.progress = value } }
                )
                let saved = try LocalFileSaver(folderStore: folderStore).copy(temporary, fileExtension: "gif")
                try? FileManager.default.removeItem(at: temporary)
                self?.toast.show("Saved \(saved.lastPathComponent)", symbol: "checkmark.circle")
                self?.window?.close()
            } catch GIFExportError.cancelled {
                self?.model.isExporting = false
            } catch {
                try? FileManager.default.removeItem(at: temporary)
                self?.model.isExporting = false
                self?.model.errorMessage = error.localizedDescription
            }
        }
    }

    private func cancel() {
        if model.isExporting {
            exportTask?.cancel()
        } else {
            window?.close()
        }
    }
}

private struct GIFExportView: View {
    let model: GIFExportModel
    let settings: SettingsModel
    let info: VideoInfo
    let onExport: () -> Void
    let onCancel: () -> Void

    private var mode: Binding<GIFExportMode> {
        Binding(
            get: { settings.settings.gifExportMode },
            set: { newMode in settings.update { $0.updating(gifExportMode: newMode) } }
        )
    }

    /// Live estimate, recalculated whenever a control changes.
    private var estimate: String {
        let resolved = settings.settings.gifExportMode.settings(sourceFramesPerSecond: info.framesPerSecond)
        return GIFExportSettings.formatted(byteCount: resolved.estimatedByteCount(width: info.width, height: info.height, duration: info.duration))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export as GIF").font(.headline)

            GIFSettingsView(mode: mode, sourceFramesPerSecond: info.framesPerSecond, recordingDuration: info.duration)
                .disabled(model.isExporting)

            HStack {
                Text("Estimated size").foregroundStyle(.secondary)
                Spacer()
                Text(estimate).monospacedDigit()
            }

            if model.isExporting {
                ProgressView(value: model.progress)
            }
            if let message = model.errorMessage {
                Text(message).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(model.isExporting ? "Stop" : "Cancel", action: onCancel)
                Button("Export", action: onExport)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isExporting)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
