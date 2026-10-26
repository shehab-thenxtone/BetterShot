import CoreGraphics

/// Maps between canvas points (the document's space) and view points: the canvas is shown centred,
/// shrunk to fit but never enlarged beyond actual size.
public struct Viewport: Equatable, Sendable {
    public let scale: CGFloat
    /// Where the canvas's top-left corner sits in the view.
    public let origin: CGPoint
    private let canvasSize: CGSize

    public init(canvasSize: CGSize, viewSize: CGSize, padding: CGFloat = 0) {
        self.canvasSize = canvasSize
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            scale = 1
            origin = .zero
            return
        }
        let availableWidth = max(viewSize.width - 2 * padding, 1)
        let availableHeight = max(viewSize.height - 2 * padding, 1)
        scale = min(1, availableWidth / canvasSize.width, availableHeight / canvasSize.height)
        origin = CGPoint(
            x: (viewSize.width - canvasSize.width * scale) / 2,
            y: (viewSize.height - canvasSize.height * scale) / 2
        )
    }

    public func toCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / scale, y: (point.y - origin.y) / scale)
    }

    public func toView(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
    }

    public func toView(_ rect: CGRect) -> CGRect {
        CGRect(origin: toView(rect.origin), size: CGSize(width: rect.width * scale, height: rect.height * scale))
    }

    public var canvasRectInView: CGRect {
        toView(CGRect(origin: .zero, size: canvasSize))
    }
}
