import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class CountdownModel {
    var remaining = 0
}

/// The Self-Timer's on-screen countdown: a big number in the middle of the display under the cursor.
/// Click it to cancel. It's one of BetterShot's own windows, so it never appears in the capture.
@MainActor
final class CountdownController {
    private static let tick: Duration = .milliseconds(100)
    private static let ticksPerSecond = 10

    private let model = CountdownModel()
    private var panel: NSPanel?
    private var isCancelled = false

    /// Counts down from `seconds`; true if it reached zero, false if the user cancelled.
    func run(seconds: Int) async -> Bool {
        isCancelled = false
        show()
        defer { hide() }

        for remaining in stride(from: seconds, through: 1, by: -1) {
            model.remaining = remaining
            for _ in 0..<Self.ticksPerSecond {
                try? await Task.sleep(for: Self.tick)
                if isCancelled || Task.isCancelled { return false }
            }
        }
        return true
    }

    private func cancel() {
        isCancelled = true
        hide() // disappear immediately; the loop above notices within a tenth of a second
    }

    private func show() {
        hide()
        let size = CGSize(width: 180, height: 180)
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: CountdownView(model: model, onCancel: { [weak self] in self?.cancel() }))
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let frame = NSScreen.underCursor?.frame ?? .zero
        panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct CountdownView: View {
    let model: CountdownModel
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text("\(model.remaining)")
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("Click to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150, height: 150)
        .background(.regularMaterial, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .padding(15)
        .contentShape(Circle())
        .onTapGesture(perform: onCancel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capturing in \(model.remaining) seconds")
        .accessibilityHint("Click to cancel")
        .accessibilityAddTraits(.isButton)
    }
}
