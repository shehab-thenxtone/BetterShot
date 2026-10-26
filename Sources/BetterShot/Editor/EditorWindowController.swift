import AppKit
import BetterShotAnnotations
import BetterShotCore
import BetterShotServices
import SwiftUI
import UniformTypeIdentifiers

/// One editor window: owns the model, the Save-as / Open panels and the Merge capture round-trip.
@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private static let toolbarHeight: CGFloat = 53
    private static let minimumSize = CGSize(width: 900, height: 420)

    private let model: EditorModel
    private let folderStore: any SaveFolderStoring
    private let settings: () -> AppSettings
    private let captureForMerge: @MainActor (CaptureMode) async -> CGImage?
    private let onDone: @MainActor (CGImage) -> Void
    private var window: NSWindow?

    var onClose: (@MainActor (EditorWindowController) -> Void)?

    init(
        image: CGImage,
        pointScale: CGFloat,
        stylesStore: UserDefaultsToolStylesStore,
        folderStore: any SaveFolderStoring,
        settings: @escaping () -> AppSettings,
        captureForMerge: @escaping @MainActor (CaptureMode) async -> CGImage?,
        onDone: @escaping @MainActor (CGImage) -> Void
    ) {
        model = EditorModel(image: image, pointScale: pointScale, stylesStore: stylesStore)
        self.folderStore = folderStore
        self.settings = settings
        self.captureForMerge = captureForMerge
        self.onDone = onDone
        super.init()
        window = makeWindow()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Window

    private func makeWindow() -> NSWindow {
        let canvas = model.document.canvasSize
        let visibleHeight = NSScreen.underCursor?.visibleFrame.height ?? 900
        let size = CGSize(
            width: max(Self.minimumSize.width, canvas.width + 64),
            height: min(max(Self.minimumSize.height, canvas.height + Self.toolbarHeight + 64), visibleHeight * 0.9)
        )

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = Self.minimumSize
        window.isReleasedWhenClosed = false
        window.delegate = self

        let actions = EditorActions(
            saveAs: { [weak self] in self?.saveAs() },
            done: { [weak self] in self?.done() },
            mergeImport: { [weak self] in self?.importImage() },
            mergeCapture: { [weak self] mode in self?.captureImage(mode) }
        )
        window.contentView = NSHostingView(rootView: EditorRootView(model: model, actions: actions))
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        model.onChange = nil
        model.focusCanvas = nil
        onClose?(self)
    }

    // MARK: Done

    /// Flattens the annotations onto the image and hands it back for the preview popup.
    private func done() {
        guard let image = model.flattened() else {
            CaptureAlerts.presentInfo(title: "Couldn't finish", message: "The edited image couldn't be rendered.", style: .warning)
            return
        }
        let handler = onDone
        window?.close()
        handler(image)
    }

    // MARK: Save as…

    private func saveAs() {
        guard let image = model.flattened() else {
            CaptureAlerts.presentInfo(title: "Couldn't save", message: "The edited image couldn't be rendered.", style: .warning)
            return
        }
        let chooser = FormatChooser(template: settings().filenameTemplate)
        let panel = chooser.makePanel(directory: folderStore.folder)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try ImageExporter.data(for: image, format: chooser.format, pointScale: model.pointScale)
            try data.write(to: url, options: .atomic)
            folderStore.setFolder(url.deletingLastPathComponent()) // Save As… is the one place the remembered folder changes
        } catch let error as SaveError {
            CaptureAlerts.present(error)
        } catch {
            CaptureAlerts.present(SaveError.writeFailed(error.localizedDescription))
        }
    }

    // MARK: Merge

    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose an image to add to the canvas"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            CaptureAlerts.presentInfo(title: "Couldn't open image", message: "\(url.lastPathComponent) isn't a readable image.", style: .warning)
            return
        }
        model.merge(image)
    }

    /// Hides the editor while the capture overlay runs, then merges the result.
    private func captureImage(_ mode: CaptureMode) {
        Task {
            window?.orderOut(nil)
            let image = await captureForMerge(mode)
            show()
            if let image { model.merge(image) }
        }
    }
}

/// The format popup shown beside the file name in the Save panel.
@MainActor
private final class FormatChooser: NSObject {
    private(set) var format: ExportFormat = .png
    private let template: FilenameTemplate
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private weak var panel: NSSavePanel?

    init(template: FilenameTemplate) {
        self.template = template
        super.init()
        popup.addItems(withTitles: ExportFormat.allCases.map(\.displayName))
        popup.target = self
        popup.action = #selector(formatChanged)
    }

    func makePanel(directory: URL) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.directoryURL = directory
        panel.canCreateDirectories = true
        panel.accessoryView = accessoryView()
        self.panel = panel
        apply(.png)
        return panel
    }

    @objc private func formatChanged() {
        apply(ExportFormat.allCases[popup.indexOfSelectedItem])
    }

    private func apply(_ newFormat: ExportFormat) {
        format = newFormat
        panel?.allowedContentTypes = [newFormat.contentType]
        panel?.nameFieldStringValue = template.filename(for: Date(), fileExtension: newFormat.fileExtension)
    }

    private func accessoryView() -> NSView {
        let label = NSTextField(labelWithString: "Format:")
        let stack = NSStackView(views: [label, popup])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return stack
    }
}
