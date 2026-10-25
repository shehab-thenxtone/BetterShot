import CoreGraphics

/// Pure rectangle math for the capture overlay. All values are in points.
public enum SelectionGeometry {
    /// Smallest selection (per side) that counts as an intentional drag rather than a click.
    public static let minimumSide: CGFloat = 4

    /// Normalised rect between two drag points, snapped to whole points for pixel-perfect edges.
    public static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let a = CGPoint(x: start.x.rounded(), y: start.y.rounded())
        let b = CGPoint(x: end.x.rounded(), y: end.y.rounded())
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Translates `rect` by `delta`, keeping its size and keeping it inside `bounds`.
    /// Used for arrow-key nudging and Space-to-reposition while dragging.
    public static func moved(_ rect: CGRect, by delta: CGSize, within bounds: CGRect) -> CGRect {
        let x = min(max(rect.minX + delta.width, bounds.minX), bounds.maxX - rect.width)
        let y = min(max(rect.minY + delta.height, bounds.minY), bounds.maxY - rect.height)
        return CGRect(x: max(x, bounds.minX), y: max(y, bounds.minY), width: rect.width, height: rect.height)
    }

    /// Crops `rect` to `bounds`; `.zero` when they don't overlap.
    public static func clamped(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        let intersection = rect.intersection(bounds)
        return intersection.isNull ? .zero : intersection
    }

    public static func isUsable(_ rect: CGRect) -> Bool {
        rect.width >= minimumSide && rect.height >= minimumSide
    }

    /// AppKit global rect (bottom-left origin) → display-local rect with a top-left origin,
    /// which is what ScreenCaptureKit's `sourceRect` expects.
    public static func displayLocalRect(fromGlobal rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// `CGWindowListCopyWindowInfo` bounds (top-left origin on the primary display) → AppKit global rect.
    public static func appKitRect(fromWindowListBounds bounds: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: bounds.minX, y: primaryScreenHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }
}
