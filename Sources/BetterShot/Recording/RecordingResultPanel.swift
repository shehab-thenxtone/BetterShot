import AVFoundation
import AppKit
import BetterShotCore
import BetterShotServices
import Observation
import SwiftUI

@MainActor
@Observable
final class RecordingResultModel {
    let info: VideoInfo
    var thumbnail: NSImage?

    init(info: VideoInfo) {
        self.info = info
    }
}

struct RecordingResultActions {
    let save: @MainActor () -> Void
    let exportGIF: @MainActor () -> Void
    let copy: @MainActor () -> Void
    let close: @MainActor () -> Void
}

/// What you see after a recording stops: a thumbnail and the ways to keep it. Saving as MP4 is the primary
/// action (MP4 is the default format); GIF export opens its own window. It stays until you act, because a
/// recording can't be recovered from the clipboard like a screenshot.
struct RecordingResultView: View {
    static let size = CGSize(width: 280, height: 220)
    static let shadowInset: CGFloat = 10

    let model: RecordingResultModel
    let actions: RecordingResultActions

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.35))
                    if let thumbnail = model.thumbnail {
                        Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(radius: 3)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

                Button(action: actions.close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("Close (the recording stays in Open…)")
                .accessibilityLabel("Close")
            }

            Text("Recording · \(RecordingTime.clockString(model.info.duration)) · \(model.info.width)×\(model.info.height)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Save MP4", action: actions.save)
                    .buttonStyle(.borderedProminent)
                    .help("Save to the Screenshots folder")
                Button("Export GIF…", action: actions.exportGIF)
                Button(action: actions.copy) { Image(systemName: "doc.on.doc") }
                    .help("Copy the recording file")
                    .accessibilityLabel("Copy recording")
            }
        }
        .padding(14)
        .frame(width: Self.size.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(Self.shadowInset)
    }
}

/// Shows the result card at the bottom-right of the display under the cursor.
@MainActor
final class RecordingResultController {
    private var panel: NSPanel?

    func show(url: URL, info: VideoInfo, actions: RecordingResultActions) {
        dismiss()

        let model = RecordingResultModel(info: info)
        let size = CGSize(
            width: RecordingResultView.size.width + RecordingResultView.shadowInset * 2,
            height: RecordingResultView.size.height + RecordingResultView.shadowInset * 2
        )
        let panel = ResultPanel(contentRect: CGRect(origin: .zero, size: size))
        panel.contentView = NSHostingView(rootView: RecordingResultView(model: model, actions: actions))
        panel.onCancel = { actions.close() }

        let visible = NSScreen.underCursor?.visibleFrame ?? .zero
        panel.setFrameOrigin(CGPoint(x: visible.maxX - size.width - 12 + RecordingResultView.shadowInset, y: visible.minY + 12 - RecordingResultView.shadowInset))
        panel.orderFrontRegardless()
        self.panel = panel

        Task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 560, height: 320)
            if let image = try? await generator.image(at: .zero).image {
                model.thumbnail = NSImage(cgImage: image, size: .zero)
            }
        }
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// Non-activating, so the card never steals focus; takes key only when clicked, which lets Esc close it.
private final class ResultPanel: NSPanel {
    var onCancel: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { true }

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func cancelOperation(_ sender: Any?) {
        MainActor.assumeIsolated { onCancel?() }
    }
}
