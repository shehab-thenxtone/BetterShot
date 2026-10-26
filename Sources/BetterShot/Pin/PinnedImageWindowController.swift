import AppKit
import BetterShotCore
import SwiftUI

/// One pinned image: a floating, always-on-top window you can drag by its background and resize from its
/// edges (aspect ratio locked). It never takes focus from the app you're working in.
@MainActor
final class PinnedImageWindowController: NSObject, NSWindowDelegate {
    private static let minimumSide: CGFloat = 80
    private static let maximumScreenFraction: CGFloat = 0.6

    private var panel: NSPanel?
    /// The pinned picture, so closing the pin can record it for "Restore Recently Closed File".
    let image: CGImage
    var onClose: (@MainActor (PinnedImageWindowController) -> Void)?

    /// `slot` offsets the window from the screen centre so successive pins cascade instead of stacking exactly.
    init(
        image: CGImage,
        pointScale: CGFloat,
        slot: Int,
        actions: ResultActions,
        openEditor: @escaping @MainActor (CGImage) -> Void
    ) {
        self.image = image
        super.init()

        let visible = NSScreen.underCursor?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let imagePoints = CGSize(width: CGFloat(image.width) / pointScale, height: CGFloat(image.height) / pointScale)
        let size = PinPlacement.fittedSize(
            for: imagePoints,
            within: CGSize(width: visible.width * Self.maximumScreenFraction, height: visible.height * Self.maximumScreenFraction),
            minimumSide: Self.minimumSide
        )
        let offset = PinPlacement.cascadeOffset(forIndex: slot)
        let frame = CGRect(
            x: visible.midX - size.width / 2 + offset.width,
            y: visible.midY - size.height / 2 + offset.height,
            width: size.width,
            height: size.height
        )

        let panel = makePanel(frame: frame)
        let pinActions = PinnedImageActions(
            copy: { actions.copy(image) },
            save: { actions.save(image) },
            edit: { openEditor(image) },
            close: { [weak self] in self?.close() }
        )
        panel.contentView = NSHostingView(rootView: PinnedImageView(image: NSImage(cgImage: image, size: .zero), actions: pinActions))
        self.panel = panel
    }

    func show() {
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
        onClose?(self)
    }

    // MARK: Window

    private func makePanel(frame: CGRect) -> NSPanel {
        // Titled + hidden title bar rather than borderless: the system then provides edge/corner resizing and a shadow.
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        panel.contentAspectRatio = frame.size
        let shrink = min(1, Self.minimumSide / min(frame.width, frame.height))
        panel.contentMinSize = CGSize(width: frame.width * shrink, height: frame.height * shrink)
        return panel
    }
}
