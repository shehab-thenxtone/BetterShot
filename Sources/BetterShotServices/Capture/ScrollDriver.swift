import BetterShotCore
import CoreGraphics

/// Scrolls whatever is under a screen point by posting scroll-wheel events, like a mouse wheel would.
/// Requires the Accessibility permission. Coordinates are global with a top-left origin (CoreGraphics'), not AppKit's.
public struct ScrollDriver: Sendable {
    public init() {}

    /// Scrolls the content under `point` so later content comes into view: a positive `pixels` reveals what is
    /// below (vertical) or to the right (horizontal); a negative value scrolls back.
    public func scroll(by pixels: Int, axis: ScrollAxis, at point: CGPoint) {
        moveCursor(to: point) // scroll events go to the window under the pointer
        let vertical = axis == .vertical ? Int32(-pixels) : 0
        let horizontal = axis == .horizontal ? Int32(-pixels) : 0
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
            wheel1: vertical, wheel2: horizontal, wheel3: 0
        ) else { return }
        event.location = point
        event.post(tap: .cghidEventTap)
    }

    public func cursorLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    public func moveCursor(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
