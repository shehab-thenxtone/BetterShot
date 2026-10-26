import AppKit
import BetterShotCore
import Observation
import SwiftUI

/// The image a result bar is showing and whether it is currently pinned to the screen.
@MainActor
@Observable
final class ResultBarModel {
    let image: CGImage
    var isPinned = false

    init(image: CGImage) {
        self.image = image
    }

    var swiftUIImage: Image { Image(nsImage: NSImage(cgImage: image, size: .zero)) }
}

/// Shows the floating result bar for a finished capture or edit (requirements §3.4). The bar dims when idle and
/// brightens on hover; its pin button creates or closes a pinned-image window for the same picture.
@MainActor
final class ResultBarController {
    private static let idleAlpha: CGFloat = 0.35
    private static let idleDelay: TimeInterval = 2.5
    private static let autoDismissDelay: TimeInterval = 30

    private let pins: PinManager
    private let actions: ResultActions

    private var panel: ResultBarPanel?
    private var model: ResultBarModel?
    private var pinned: PinnedImageWindowController?
    private var idleTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?

    init(pins: PinManager, actions: ResultActions) {
        self.pins = pins
        self.actions = actions
    }

    /// Replaces any bar already showing. A pin made from the previous bar stays on screen.
    func show(image: CGImage, startPinned: Bool) {
        dismiss()

        let model = ResultBarModel(image: image)
        self.model = model

        let view = ResultBarView(
            model: model,
            actions: ResultBarActions(
                togglePin: { [weak self] in self?.togglePin() },
                copy: { [weak self] in self?.copy() },
                upload: { [weak self] in self?.upload() },
                dismiss: { [weak self] in self?.dismiss() }
            ),
            onHoverChange: { [weak self] isHovering in self?.hoverChanged(isHovering) }
        )

        let inset = ResultBarView.shadowInset * 2
        let size = CGSize(width: ResultBarView.size.width + inset, height: ResultBarView.size.height + inset)
        let panel = ResultBarPanel(contentRect: CGRect(origin: .zero, size: size))
        panel.contentView = NSHostingView(rootView: view)
        panel.onCancel = { [weak self] in self?.dismiss() }

        let visible = NSScreen.underCursor?.visibleFrame ?? .zero
        let origin = DockPlacement.bottomCenter(size: size, in: visible, margin: 16 - ResultBarView.shadowInset)
        panel.setFrameOrigin(origin)
        self.panel = panel

        panel.orderFrontRegardless()
        if !Self.reduceMotion {
            panel.alphaValue = 0
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        }
        scheduleIdle()
        if startPinned { pinImage() }
    }

    func dismiss() {
        idleTask?.cancel()
        dismissTask?.cancel()
        idleTask = nil
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil
        pinned = nil
    }

    // MARK: Pinning

    private func togglePin() {
        guard let model else { return }
        if let pinned {
            self.pinned = nil
            model.isPinned = false
            pinned.close()
        } else {
            pinImage()
        }
    }

    private func pinImage() {
        guard let model else { return }
        pinned = pins.pin(image: model.image) { [weak self, weak model] closed in
            // The pin was closed from its own × / context menu: reflect that on the bar.
            guard self?.pinned === closed else { return }
            self?.pinned = nil
            model?.isPinned = false
        }
        model.isPinned = true
    }

    private func copy() {
        guard let model else { return }
        actions.copy(model.image)
    }

    private func upload() {
        guard let model else { return }
        actions.upload(model.image)
    }

    // MARK: Fading

    private func hoverChanged(_ isHovering: Bool) {
        if isHovering {
            idleTask?.cancel()
            dismissTask?.cancel()
            setAlpha(1)
        } else {
            scheduleIdle()
        }
    }

    /// After a quiet moment the bar fades back so it stays out of the way; it goes away entirely much later.
    private func scheduleIdle() {
        idleTask?.cancel()
        dismissTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.idleDelay))
            guard !Task.isCancelled else { return }
            self?.setAlpha(Self.idleAlpha)
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.autoDismissDelay))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func setAlpha(_ alpha: CGFloat) {
        guard let panel else { return }
        if Self.reduceMotion {
            panel.alphaValue = alpha
        } else {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = alpha }
        }
    }

    private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

/// Borderless, non-activating panel: never steals focus, takes key only if clicked (so Esc can dismiss it).
private final class ResultBarPanel: NSPanel {
    var onCancel: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { true }

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // SwiftUI draws the shadow
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func cancelOperation(_ sender: Any?) {
        MainActor.assumeIsolated { onCancel?() }
    }
}
