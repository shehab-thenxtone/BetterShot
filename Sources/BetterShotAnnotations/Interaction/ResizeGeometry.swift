import CoreGraphics

/// The eight grab handles around a selection or crop rectangle. Coordinates use a top-left origin,
/// so `top` is the edge with the smaller y.
public enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    var movesLeft: Bool { self == .topLeft || self == .left || self == .bottomLeft }
    var movesRight: Bool { self == .topRight || self == .right || self == .bottomRight }
    var movesTop: Bool { self == .topLeft || self == .top || self == .topRight }
    var movesBottom: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }
}

/// Pure maths for dragging resize handles: used for selected annotations and for the crop rectangle.
public enum ResizeGeometry {
    public static func handlePositions(of rect: CGRect) -> [ResizeHandle: CGPoint] {
        [
            .topLeft: CGPoint(x: rect.minX, y: rect.minY),
            .top: CGPoint(x: rect.midX, y: rect.minY),
            .topRight: CGPoint(x: rect.maxX, y: rect.minY),
            .right: CGPoint(x: rect.maxX, y: rect.midY),
            .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            .bottom: CGPoint(x: rect.midX, y: rect.maxY),
            .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
            .left: CGPoint(x: rect.minX, y: rect.midY),
        ]
    }

    /// The handle nearest `point`, if any is within `tolerance`.
    public static func handle(at point: CGPoint, of rect: CGRect, tolerance: CGFloat) -> ResizeHandle? {
        handlePositions(of: rect)
            .map { (handle: $0.key, distance: hypot($0.value.x - point.x, $0.value.y - point.y)) }
            .filter { $0.distance <= tolerance }
            .min { $0.distance < $1.distance }?
            .handle
    }

    /// `rect` after dragging `handle` to `point`. The opposite edges stay fixed, sides never drop below
    /// `minimumSide`, and the result stays inside `bounds` if given. With `aspectRatio` (width / height) the
    /// shape keeps that proportion: corners pivot on the opposite corner, edges grow around the centre.
    public static func resize(
        _ rect: CGRect,
        dragging handle: ResizeHandle,
        to point: CGPoint,
        aspectRatio: CGFloat? = nil,
        within bounds: CGRect? = nil,
        minimumSide: CGFloat = 8
    ) -> CGRect {
        let target = bounds.map {
            CGPoint(x: min(max(point.x, $0.minX), $0.maxX), y: min(max(point.y, $0.minY), $0.maxY))
        } ?? point

        var left = rect.minX, right = rect.maxX, top = rect.minY, bottom = rect.maxY
        if handle.movesLeft { left = min(target.x, right - minimumSide) }
        if handle.movesRight { right = max(target.x, left + minimumSide) }
        if handle.movesTop { top = min(target.y, bottom - minimumSide) }
        if handle.movesBottom { bottom = max(target.y, top + minimumSide) }

        let proposed = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        guard let ratio = aspectRatio, ratio > 0 else { return proposed }
        return constrained(proposed, around: rect, handle: handle, ratio: ratio, bounds: bounds, minimumSide: minimumSide)
    }

    // MARK: Aspect ratio

    private static func constrained(
        _ proposed: CGRect, around original: CGRect, handle: ResizeHandle,
        ratio: CGFloat, bounds: CGRect?, minimumSide: CGFloat
    ) -> CGRect {
        let horizontal = handle.movesLeft || handle.movesRight
        let vertical = handle.movesTop || handle.movesBottom

        var width: CGFloat
        var height: CGFloat
        let anchorX = handle.movesLeft ? proposed.maxX : proposed.minX
        let anchorY = handle.movesTop ? proposed.maxY : proposed.minY
        var maxWidth = CGFloat.infinity
        var maxHeight = CGFloat.infinity

        if horizontal && vertical { // corner: pivot on the opposite corner
            width = proposed.width
            height = proposed.height
            if width / height > ratio { height = width / ratio } else { width = height * ratio }
            if let bounds {
                maxWidth = handle.movesLeft ? anchorX - bounds.minX : bounds.maxX - anchorX
                maxHeight = handle.movesTop ? anchorY - bounds.minY : bounds.maxY - anchorY
            }
        } else if vertical { // top/bottom edge: width follows, centred on the original
            height = proposed.height
            width = height * ratio
            if let bounds {
                maxHeight = handle.movesTop ? anchorY - bounds.minY : bounds.maxY - anchorY
                maxWidth = 2 * min(original.midX - bounds.minX, bounds.maxX - original.midX)
            }
        } else { // left/right edge: height follows, centred on the original
            width = proposed.width
            height = width / ratio
            if let bounds {
                maxWidth = handle.movesLeft ? anchorX - bounds.minX : bounds.maxX - anchorX
                maxHeight = 2 * min(original.midY - bounds.minY, bounds.maxY - original.midY)
            }
        }

        let shrink = min(1, maxWidth / width, maxHeight / height)
        width *= shrink
        height *= shrink
        if width < minimumSide { width = minimumSide; height = width / ratio }
        if height < minimumSide { height = minimumSide; width = height * ratio }

        let x: CGFloat
        let y: CGFloat
        if horizontal { x = handle.movesLeft ? anchorX - width : anchorX } else { x = original.midX - width / 2 }
        if vertical { y = handle.movesTop ? anchorY - height : anchorY } else { y = original.midY - height / 2 }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
