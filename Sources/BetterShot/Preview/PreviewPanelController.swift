import AppKit
import SwiftUI

/// Owns the floating preview panel: placement, fade, auto-dismiss (paused while hovered),
/// click-elsewhere and Esc dismissal. Non-modal and non-activating, so it never steals focus from the frontmost app.
@MainActor
final class PreviewPanelController {
    private static let screenMargin: CGFloat = 12

    private var panel: PreviewPanel?
    private var dismissTask: Task<Void, Never>?
    private var outsideClickMonitor: Any?
    private var autoDismissDelay: TimeInterval = 6
    private var onDiscard: (@MainActor () -> Void)?

    /// `onDiscard` runs if the popup goes away without the user acting on it: it timed out, was dismissed with Esc
    /// or a click elsewhere, or was replaced by a newer capture.
    func show(
        image: CGImage,
        isPinAvailable: Bool,
        autoDismissAfter delay: TimeInterval,
        actions: PreviewActions,
        onDiscard: @escaping @MainActor () -> Void
    ) {
        dismiss(animated: false, discarded: true) // a previous capture nobody acted on counts as discarded
        autoDismissDelay = delay
        self.onDiscard = onDiscard

        let view = PreviewPopupView(
            image: NSImage(cgImage: image, size: .zero),
            isPinAvailable: isPinAvailable,
            actions: actions,
            onHoverChange: { [weak self] isHovering in
                if isHovering { self?.cancelAutoDismiss() } else { self?.scheduleAutoDismiss() }
            }
        )
        let inset = PreviewPopupView.shadowInset * 2
        let size = CGSize(
            width: PreviewPopupView.thumbnailSize.width + inset,
            height: PreviewPopupView.thumbnailSize.height + inset
        )

        let panel = PreviewPanel(contentRect: CGRect(origin: .zero, size: size))
        panel.contentView = NSHostingView(rootView: view)
        panel.onCancel = { [weak self] in self?.dismiss(discarded: true) }
        panel.setFrameOrigin(Self.origin(for: size))
        self.panel = panel

        if Self.reduceMotion {
            panel.orderFrontRegardless()
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss(discarded: true) }
        }
        scheduleAutoDismiss()
    }

    /// `discarded` is true when nobody acted on the capture (timeout, Esc, click elsewhere); false when an action
    /// (Copy, Save, Pin, Upload, Edit) closed it, since the image then lives on elsewhere.
    func dismiss(animated: Bool = true, discarded: Bool = false) {
        cancelAutoDismiss()
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        guard let panel else { return }
        self.panel = nil
        let discardHandler = discarded ? onDiscard : nil
        onDiscard = nil
        defer { discardHandler?() }

        if animated, !Self.reduceMotion {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; panel.animator().alphaValue = 0 }) {
                MainActor.assumeIsolated { panel.orderOut(nil) } // AppKit runs completion handlers on the main thread
            }
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: Auto-dismiss

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        let delay = autoDismissDelay
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.dismiss(discarded: true)
        }
    }

    private func cancelAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    // MARK: Placement

    /// Bottom-right of the display under the cursor, inside its visible (menu bar / Dock aware) area.
    private static func origin(for size: CGSize) -> CGPoint {
        let visible = NSScreen.underCursor?.visibleFrame ?? .zero
        return CGPoint(x: visible.maxX - size.width - screenMargin + PreviewPopupView.shadowInset,
                       y: visible.minY + screenMargin - PreviewPopupView.shadowInset)
    }

    private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

/// Borderless, click-through-outside panel that can take key (for Esc) only after the user clicks it.
private final class PreviewPanel: NSPanel {
    var onCancel: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { true }

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // SwiftUI draws the shadow
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func cancelOperation(_ sender: Any?) {
        MainActor.assumeIsolated { onCancel?() }
    }
}
