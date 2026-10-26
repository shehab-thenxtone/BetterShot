import AppKit
import BetterShotCore
import SwiftUI

/// A brief, non-interactive message near the bottom of the screen ("Copied 42 characters"). It never takes
/// focus and ignores the mouse, so it can't get in the way.
@MainActor
final class ToastController {
    private static let margin: CGFloat = 90
    private static let inset: CGFloat = 10

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, symbol: String? = nil, duration: TimeInterval = 2.2) {
        dismiss()

        let hosting = NSHostingView(rootView: ToastView(message: message, symbol: symbol).padding(Self.inset))
        let size = hosting.fittingSize
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visible = NSScreen.underCursor?.visibleFrame ?? .zero
        panel.setFrameOrigin(DockPlacement.bottomCenter(size: size, in: visible, margin: Self.margin))
        panel.orderFrontRegardless()
        self.panel = panel

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ToastView: View {
    let message: String
    let symbol: String?

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol) }
            Text(message)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}
