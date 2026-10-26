import AppKit
import SwiftUI

struct PinnedImageActions {
    let copy: @MainActor () -> Void
    let save: @MainActor () -> Void
    let edit: @MainActor () -> Void
    let close: @MainActor () -> Void
}

/// A pinned image: just the picture, a hover-revealed close button and the right-click menu (requirements §3.4).
struct PinnedImageView: View {
    let image: NSImage
    let actions: PinnedImageActions

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            WindowDragArea()

            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .allowsHitTesting(false)
                .accessibilityLabel("Pinned screenshot")

            if isHovering {
                Button { actions.close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Close")
                .accessibilityLabel("Close pinned image")
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
        .contextMenu {
            Button("Copy") { actions.copy() }
            Button("Save") { actions.save() }
            Button("Open in Editor") { actions.edit() }
            Divider()
            Button("Delete") { actions.close() }
        }
    }
}
