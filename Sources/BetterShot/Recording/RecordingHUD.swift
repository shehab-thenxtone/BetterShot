import AppKit
import BetterShotCore
import Observation
import SwiftUI

@MainActor
@Observable
final class RecordingHUDModel {
    var elapsed: Double = 0
    var isPaused = false
}

/// The small always-visible control strip while recording: elapsed time, Pause/Resume and Stop. It is one of
/// BetterShot's own windows, so it never appears in the recording. Drag it anywhere.
@MainActor
final class RecordingHUDController {
    private let model = RecordingHUDModel()
    private var panel: NSPanel?
    private var ticker: Task<Void, Never>?

    /// `elapsed` is polled a few times a second for the timer.
    func show(
        elapsed: @escaping @MainActor () -> Double,
        onPauseResume: @escaping @MainActor () -> Void,
        onStop: @escaping @MainActor () -> Void
    ) {
        hide()
        model.elapsed = 0
        model.isPaused = false

        let inset = RecordingHUDView.shadowInset * 2
        let size = CGSize(width: RecordingHUDView.size.width + inset, height: RecordingHUDView.size.height + inset)
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: RecordingHUDView(model: model, onPauseResume: onPauseResume, onStop: onStop))
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visible = NSScreen.underCursor?.visibleFrame ?? .zero
        panel.setFrameOrigin(DockPlacement.bottomCenter(size: size, in: visible, margin: 40 - RecordingHUDView.shadowInset))
        panel.orderFrontRegardless()
        self.panel = panel

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.model.elapsed = elapsed()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func setPaused(_ isPaused: Bool) {
        model.isPaused = isPaused
    }

    func hide() {
        ticker?.cancel()
        ticker = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

struct RecordingHUDView: View {
    static let size = CGSize(width: 210, height: 44)
    static let shadowInset: CGFloat = 8

    let model: RecordingHUDModel
    let onPauseResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(model.isPaused ? Color.orange : Color.red)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(RecordingTime.clockString(model.elapsed))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .accessibilityLabel(model.isPaused ? "Paused at \(RecordingTime.clockString(model.elapsed))" : "Recording, \(RecordingTime.clockString(model.elapsed))")

            Spacer(minLength: 0)

            Button(action: onPauseResume) {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 28, height: 28)
                    .background(.quaternary.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .help(model.isPaused ? "Resume recording" : "Pause recording")
            .accessibilityLabel(model.isPaused ? "Resume recording" : "Pause recording")

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.red, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Stop recording")
            .accessibilityLabel("Stop recording")
        }
        .padding(.horizontal, 14)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(WindowDragArea())
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .padding(Self.shadowInset)
    }
}
