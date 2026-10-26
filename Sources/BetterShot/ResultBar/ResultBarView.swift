import AppKit
import SwiftUI

struct ResultBarActions {
    let togglePin: @MainActor () -> Void
    let copy: @MainActor () -> Void
    let upload: @MainActor () -> Void
    let dismiss: @MainActor () -> Void
}

/// The floating "Drag me" strip (layout mirrors docs/reference/result-bar.png): pin on the left, the drag
/// handle in the middle, share / copy / cloud on the right.
struct ResultBarView: View {
    static let size = CGSize(width: 400, height: 44)
    /// Transparent margin around the bar so its shadow isn't clipped by the panel.
    static let shadowInset: CGFloat = 8

    let model: ResultBarModel
    let actions: ResultBarActions
    let onHoverChange: (Bool) -> Void

    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 10) {
            barButton(
                model.isPinned ? "pin.fill" : "pin",
                label: model.isPinned ? "Unpin from screen" : "Pin to screen",
                isHighlighted: model.isPinned
            ) { actions.togglePin() }

            Spacer(minLength: 4)
            dragHandle
            Spacer(minLength: 4)

            ShareLink(item: model.swiftUIImage, preview: SharePreview("Screenshot", image: model.swiftUIImage)) {
                icon("square.and.arrow.up", isHighlighted: false)
            }
            .buttonStyle(.plain)
            .help("Share")
            .accessibilityLabel("Share")

            barButton(didCopy ? "checkmark" : "doc.on.doc", label: "Copy to clipboard", isHighlighted: false) { copy() }
            barButton("icloud.and.arrow.up", label: "Upload to default destination", isHighlighted: false) { actions.upload() }
        }
        .padding(.horizontal, 10)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(WindowDragArea())
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .padding(Self.shadowInset)
        .onHover(perform: onHoverChange)
        .contextMenu { Button("Dismiss") { actions.dismiss() } }
    }

    private var dragHandle: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
            Text("Drag me").font(.system(size: 12, weight: .medium))
            Image(systemName: "line.3.horizontal")
        }
        .foregroundStyle(.secondary)
        .frame(width: 130, height: 28)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .allowsHitTesting(false) // the bar's background drags the window
        .accessibilityHidden(true)
    }

    private func icon(_ symbol: String, isHighlighted: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .frame(width: 30, height: 28)
            .background(isHighlighted ? Color.accentColor.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func barButton(_ symbol: String, label: String, isHighlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { icon(symbol, isHighlighted: isHighlighted) }
            .buttonStyle(.plain)
            .help(label)
            .accessibilityLabel(label)
    }

    private func copy() {
        actions.copy()
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            didCopy = false
        }
    }
}
