import CoreGraphics

/// Whole-image operations that change the base pixels (as opposed to annotations drawn over them).
enum ImageOperations {
    /// `right` placed after `left`, top-aligned, on a transparent canvas as wide as both and as tall as the taller.
    static func appendingRight(_ left: CGImage, _ right: CGImage) -> CGImage? {
        let width = left.width + right.width
        let height = max(left.height, right.height)
        guard let context = AnnotationRenderer.makeContext(width: width, height: height) else { return nil }

        // CoreGraphics origin is bottom-left, so top-aligned means y = height - imageHeight.
        context.draw(left, in: CGRect(x: 0, y: height - left.height, width: left.width, height: left.height))
        context.draw(right, in: CGRect(x: left.width, y: height - right.height, width: right.width, height: right.height))
        return context.makeImage()
    }
}
