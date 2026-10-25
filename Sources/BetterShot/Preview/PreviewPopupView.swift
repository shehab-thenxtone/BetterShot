import AppKit
import SwiftUI

/// What the popup's controls do. Built by `PostCaptureFlow`; the view knows nothing about capture or storage.
struct PreviewActions {
    let copy: @MainActor () -> Void
    let save: @MainActor () -> Void
    let pin: @MainActor () -> Void
    let upload: @MainActor () -> Void
    let edit: @MainActor () -> Void
}

/// Post-capture thumbnail (layout mirrors docs/reference/post-capture-popup.png).
struct PreviewPopupView: View {
    static let thumbnailSize = CGSize(width: 240, height: 150)
    /// Transparent margin around the thumbnail so the shadow isn't clipped by the panel.
    static let shadowInset: CGFloat = 10

    let image: NSImage
    let isPinAvailable: Bool
    let actions: PreviewActions
    let onHoverChange: (Bool) -> Void

    var body: some View {
        ZStack {
            Button(action: { actions.edit() }) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
                    .clipped()
            }
            .buttonStyle(.plain)
            .help("Open in editor")
            .accessibilityLabel("Captured screenshot. Open in editor")

            VStack(spacing: 8) {
                pill("Copy", help: "Copy to clipboard") { actions.copy() }
                pill("Save", help: "Save to the Screenshots folder") { actions.save() }
            }

            VStack {
                HStack {
                    Spacer()
                    badge("pin.fill", label: "Pin to screen", isEnabled: isPinAvailable) { actions.pin() }
                }
                Spacer()
                HStack {
                    Spacer()
                    badge("icloud.and.arrow.up", label: "Upload to default destination", isEnabled: true) { actions.upload() }
                }
            }
            .padding(8)
        }
        .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(Self.shadowInset)
        .onHover(perform: onHoverChange)
    }

    private func pill(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func badge(_ symbol: String, label: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .help(isEnabled ? label : "\(label) (coming soon)")
        .accessibilityLabel(label)
    }
}
