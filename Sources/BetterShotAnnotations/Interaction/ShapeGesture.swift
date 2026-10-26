import CoreGraphics

/// Turns a mouse drag into the annotation it should create. Pure, so the canvas only has to forward points.
public enum ShapeGesture {
    private static let minimumShapeSide: CGFloat = 2
    private static let minimumRegionSide: CGFloat = 4
    private static let minimumLineLength: CGFloat = 3

    /// The annotation `tool` makes when dragged from `start` to `end`, or nil for non-drag tools and
    /// drags too small to be intentional. `constrained` (Shift) makes shapes square and snaps lines to 45°.
    public static func kind(for tool: AnnotationTool, from start: CGPoint, to end: CGPoint, constrained: Bool) -> AnnotationKind? {
        switch tool {
        case .rectangle, .filledRectangle, .ellipse:
            let rect = box(from: start, to: constrained ? squareEnd(from: start, to: end) : end)
            guard rect.width >= minimumShapeSide, rect.height >= minimumShapeSide else { return nil }
            return tool == .ellipse ? .ellipse(rect) : .rectangle(rect, isFilled: tool == .filledRectangle)
        case .pixelate, .textHighlighter:
            let rect = box(from: start, to: end)
            guard rect.width >= minimumRegionSide, rect.height >= minimumRegionSide else { return nil }
            return tool == .pixelate ? .pixelate(rect) : .textHighlight(rect)
        case .line, .arrow:
            let tip = constrained ? snappedEnd(from: start, to: end) : end
            guard hypot(tip.x - start.x, tip.y - start.y) >= minimumLineLength else { return nil }
            return tool == .line ? .line(from: start, to: tip) : .arrow(from: start, to: tip)
        case .select, .text, .stepCounter, .marker, .pen:
            return nil
        }
    }

    private static func box(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    /// Equal-sided corner in the direction of the drag.
    private static func squareEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
    }

    /// Same length, angle rounded to the nearest multiple of 45°.
    private static func snappedEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = hypot(dx, dy)
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        return CGPoint(x: start.x + length * cos(angle), y: start.y + length * sin(angle))
    }
}
