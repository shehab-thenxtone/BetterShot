import AppKit
import BetterShotCore

/// One per display. Draws the dimmed crosshair overlay and turns mouse/keyboard input into a `SelectionOutcome`.
///
/// - Drag: select an area (pixel-snapped). Hold Space while dragging to move the selection.
/// - Arrow keys: nudge the selection by 1pt (10pt with Shift).
/// - Hover + click: pick a window (Window and All-In-One modes).
/// - Return: whole display (All-In-One). Esc: cancel.
@MainActor
final class SelectionOverlayView: NSView {
    private let mode: SelectionMode
    private let candidateWindows: [WindowInfo]
    private let screen: NSScreen
    private let onOutcome: (SelectionOutcome) -> Void

    private var hoveredWindow: WindowInfo?
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var lastDragPoint: CGPoint?
    private var selection: CGRect?
    private var isSpaceHeld = false

    init(mode: SelectionMode, candidateWindows: [WindowInfo], screen: NSScreen, onOutcome: @escaping (SelectionOutcome) -> Void) {
        self.mode = mode
        self.candidateWindows = candidateWindows
        self.screen = screen
        self.onOutcome = onOutcome
        super.init(frame: CGRect(origin: .zero, size: screen.frame.size))
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        guard mode.allowsWindow else { return }
        let global = globalPoint(from: localPoint(of: event))
        let hit = WindowInfo.topmost(at: global, in: candidateWindows)
        if hit != hoveredWindow {
            hoveredWindow = hit
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard mode.allowsArea else { return }
        let point = localPoint(of: event)
        dragStart = point
        dragCurrent = point
        lastDragPoint = point
        selection = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode.allowsArea, let start = dragStart else { return }
        let point = localPoint(of: event)

        if isSpaceHeld, let last = lastDragPoint {
            translateSelection(by: CGSize(width: point.x - last.x, height: point.y - last.y))
        } else {
            let end = CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
            dragCurrent = end
            selection = SelectionGeometry.rect(from: start, to: end)
        }
        lastDragPoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { resetDrag() }
        if let selection, SelectionGeometry.isUsable(selection) {
            onOutcome(.area(displayID: screen.displayID, globalRect: selection.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)))
        } else if mode.allowsWindow, let hoveredWindow {
            onOutcome(.window(hoveredWindow))
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case Key.escape: onOutcome(.cancelled)
        case Key.space: isSpaceHeld = true
        case Key.return, Key.keypadEnter:
            if mode.allowsFullscreenShortcut { onOutcome(.fullscreen(displayID: screen.displayID)) }
        case Key.left: nudge(dx: -step, dy: 0)
        case Key.right: nudge(dx: step, dy: 0)
        case Key.down: nudge(dx: 0, dy: -step) // AppKit y grows upward
        case Key.up: nudge(dx: 0, dy: step)
        default: super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == Key.space { isSpaceHeld = false } else { super.keyUp(with: event) }
    }

    // MARK: Selection editing

    private func nudge(dx: CGFloat, dy: CGFloat) {
        guard selection != nil else { return }
        translateSelection(by: CGSize(width: dx, height: dy))
        needsDisplay = true
    }

    /// Moves the selection and its drag anchors together so a later drag continues from the new spot.
    private func translateSelection(by delta: CGSize) {
        guard let current = selection, let start = dragStart, let end = dragCurrent else { return }
        let moved = SelectionGeometry.moved(current, by: delta, within: bounds)
        let applied = CGSize(width: moved.minX - current.minX, height: moved.minY - current.minY)
        selection = moved
        dragStart = CGPoint(x: start.x + applied.width, y: start.y + applied.height)
        dragCurrent = CGPoint(x: end.x + applied.width, y: end.y + applied.height)
    }

    private func resetDrag() {
        dragStart = nil
        dragCurrent = nil
        lastDragPoint = nil
        selection = nil
        needsDisplay = true
    }

    // MARK: Coordinates

    private func localPoint(of event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

    private func globalPoint(from local: CGPoint) -> CGPoint {
        CGPoint(x: local.x + screen.frame.minX, y: local.y + screen.frame.minY)
    }

    private func localRect(for window: WindowInfo) -> CGRect {
        window.frame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY).intersection(bounds)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Near-transparent base so the whole overlay keeps receiving mouse events.
        NSColor.black.withAlphaComponent(0.01).setFill()
        bounds.fill()

        let highlight = selection ?? hoveredWindow.map(localRect(for:))
        let dim = NSBezierPath(rect: bounds)
        if let highlight, !highlight.isNull {
            dim.append(NSBezierPath(rect: highlight))
            dim.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.35).setFill()
        dim.fill()

        guard let highlight, !highlight.isNull else { return }
        let border = NSBezierPath(rect: highlight)
        border.lineWidth = selection == nil ? 3 : 1.5
        NSColor.controlAccentColor.setStroke()
        border.stroke()

        if let selection { drawSizeLabel(for: selection) }
    }

    private func drawSizeLabel(for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let labelSize = CGSize(width: size.width + padding * 2, height: size.height + padding)
        let aboveY = rect.maxY + 6
        let originY = aboveY + labelSize.height <= bounds.maxY ? aboveY : rect.minY - labelSize.height - 6
        let origin = CGPoint(x: min(max(rect.minX, 0), bounds.maxX - labelSize.width), y: max(originY, 0))
        let background = CGRect(origin: origin, size: labelSize)

        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: background.minX + padding, y: background.minY + padding / 2), withAttributes: attributes)
    }
}

/// Virtual key codes (kVK_*) used by the overlay.
private enum Key {
    static let `return`: UInt16 = 36
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    static let keypadEnter: UInt16 = 76
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
}
