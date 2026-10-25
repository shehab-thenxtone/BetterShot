import AppKit
import BetterShotCore
import BetterShotServices

/// Shows the selection overlay on every display and suspends until the user picks something or cancels.
@MainActor
final class SelectionOverlayController {
    private var overlayWindows: [OverlayWindow] = []
    private var continuation: CheckedContinuation<SelectionOutcome, Never>?

    func run(mode: SelectionMode) async -> SelectionOutcome {
        guard continuation == nil else { return .cancelled } // one selection at a time

        let candidateWindows = mode.allowsWindow ? WindowLocator.onScreenWindows() : []
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            let cursor = NSEvent.mouseLocation
            var keyWindow: OverlayWindow?
            for screen in NSScreen.screens {
                let view = SelectionOverlayView(mode: mode, candidateWindows: candidateWindows, screen: screen) { [weak self] outcome in
                    self?.finish(with: outcome)
                }
                let window = OverlayWindow(screen: screen, contentView: view)
                overlayWindows.append(window)
                window.orderFrontRegardless()
                if screen.frame.contains(cursor) { keyWindow = window }
            }

            NSApp.activate(ignoringOtherApps: true)
            let target = keyWindow ?? overlayWindows.first
            target?.makeKeyAndOrderFront(nil)
            target?.makeFirstResponder(target?.contentView)
        }
    }

    private func finish(with outcome: SelectionOutcome) {
        guard let continuation else { return }
        self.continuation = nil
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        continuation.resume(returning: outcome)
    }
}

/// Borderless, click-capturing window covering one display above everything else.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    init(screen: NSScreen, contentView: NSView) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        self.contentView = contentView
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(screen.frame, display: false)
    }
}
