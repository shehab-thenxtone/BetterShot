import CoreGraphics

/// The geometry of one annotation, in document points with a top-left origin.
/// Pure data: editing produces a new value, rendering is a separate step.
public enum AnnotationKind: Equatable, Sendable {
    case rectangle(CGRect, isFilled: Bool)
    case ellipse(CGRect)
    case line(from: CGPoint, to: CGPoint)
    case arrow(from: CGPoint, to: CGPoint)
    /// `origin` is the top-left of the text box.
    case text(String, origin: CGPoint, fontSize: CGFloat)
    /// Censors the content beneath it when flattened (requirements §4.6).
    case pixelate(CGRect)
    case stepCounter(center: CGPoint, number: Int)
    case marker(points: [CGPoint])
    case pen(points: [CGPoint])
    /// Tint over text. Phase 9 snaps this rect to detected text lines.
    case textHighlight(CGRect)

    public static let stepCounterDiameter: CGFloat = 28

    // MARK: Bounds

    public var bounds: CGRect {
        switch self {
        case .rectangle(let rect, _), .ellipse(let rect), .pixelate(let rect), .textHighlight(let rect):
            rect
        case .line(let from, let to), .arrow(let from, let to):
            Self.boundingRect(of: [from, to])
        case .text(let string, let origin, let fontSize):
            CGRect(origin: origin, size: TextLayout.measure(string, fontSize: fontSize))
        case .stepCounter(let center, _):
            CGRect(
                x: center.x - Self.stepCounterDiameter / 2,
                y: center.y - Self.stepCounterDiameter / 2,
                width: Self.stepCounterDiameter,
                height: Self.stepCounterDiameter
            )
        case .marker(let points), .pen(let points):
            Self.boundingRect(of: points)
        }
    }

    // MARK: Hit testing

    /// Whether `point` is on this annotation, give or take `tolerance` points (for easy clicking).
    public func contains(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        switch self {
        case .line(let from, let to), .arrow(let from, let to):
            Self.distance(from: point, toSegment: from, to) <= tolerance
        case .marker(let points), .pen(let points):
            Self.isNear(point, polyline: points, tolerance: tolerance)
        default:
            bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    // MARK: Editing

    public func translated(by delta: CGSize) -> AnnotationKind {
        mapPoints { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
    }

    /// Maps this geometry from `old` to `new` (resize handles in the editor). Text scales with height.
    public func transformed(from old: CGRect, to new: CGRect) -> AnnotationKind {
        let scaleX = old.width > 0 ? new.width / old.width : 1
        let scaleY = old.height > 0 ? new.height / old.height : 1
        let mapped = mapPoints { CGPoint(x: new.minX + ($0.x - old.minX) * scaleX, y: new.minY + ($0.y - old.minY) * scaleY) }

        // `mapPoints` moves rect origins but not their size; apply the scale to sizes and font here.
        switch (self, mapped) {
        case (.rectangle(let rect, _), .rectangle(let moved, let filled)):
            return .rectangle(CGRect(origin: moved.origin, size: CGSize(width: rect.width * scaleX, height: rect.height * scaleY)), isFilled: filled)
        case (.ellipse(let rect), .ellipse(let moved)):
            return .ellipse(CGRect(origin: moved.origin, size: CGSize(width: rect.width * scaleX, height: rect.height * scaleY)))
        case (.pixelate(let rect), .pixelate(let moved)):
            return .pixelate(CGRect(origin: moved.origin, size: CGSize(width: rect.width * scaleX, height: rect.height * scaleY)))
        case (.textHighlight(let rect), .textHighlight(let moved)):
            return .textHighlight(CGRect(origin: moved.origin, size: CGSize(width: rect.width * scaleX, height: rect.height * scaleY)))
        case (.text(_, _, let fontSize), .text(let string, let origin, _)):
            return .text(string, origin: origin, fontSize: max(1, fontSize * scaleY))
        default:
            return mapped
        }
    }

    // MARK: Helpers

    /// Applies `transform` to every point (rect origins, line ends, centres, freehand points).
    private func mapPoints(_ transform: (CGPoint) -> CGPoint) -> AnnotationKind {
        switch self {
        case .rectangle(let rect, let filled): .rectangle(CGRect(origin: transform(rect.origin), size: rect.size), isFilled: filled)
        case .ellipse(let rect): .ellipse(CGRect(origin: transform(rect.origin), size: rect.size))
        case .pixelate(let rect): .pixelate(CGRect(origin: transform(rect.origin), size: rect.size))
        case .textHighlight(let rect): .textHighlight(CGRect(origin: transform(rect.origin), size: rect.size))
        case .line(let from, let to): .line(from: transform(from), to: transform(to))
        case .arrow(let from, let to): .arrow(from: transform(from), to: transform(to))
        case .text(let string, let origin, let fontSize): .text(string, origin: transform(origin), fontSize: fontSize)
        case .stepCounter(let center, let number): .stepCounter(center: transform(center), number: number)
        case .marker(let points): .marker(points: points.map(transform))
        case .pen(let points): .pen(points: points.map(transform))
        }
    }

    private static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func isNear(_ point: CGPoint, polyline points: [CGPoint], tolerance: CGFloat) -> Bool {
        if points.count == 1, let only = points.first { return hypot(point.x - only.x, point.y - only.y) <= tolerance }
        return zip(points, points.dropFirst()).contains { distance(from: point, toSegment: $0, $1) <= tolerance }
    }

    private static func distance(from point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - a.x, point.y - a.y) }
        let t = min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared, 0), 1)
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
    }
}
