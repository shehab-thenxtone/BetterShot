import AppKit
import SwiftUI

/// Place behind SwiftUI content to let empty space drag the window (borderless and hidden-title-bar windows
/// have no title bar to grab).
struct WindowDragArea: NSViewRepresentable {
    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ view: NSView, context: Context) {}
}
