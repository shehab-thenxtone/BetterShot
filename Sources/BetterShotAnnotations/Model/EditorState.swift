import CoreGraphics

/// A captured image with identity-based equality, so editor snapshots compare cheaply
/// without comparing pixels.
public final class BaseImage: Equatable, @unchecked Sendable { // CGImage is immutable
    public let cgImage: CGImage

    public init(_ cgImage: CGImage) {
        self.cgImage = cgImage
    }

    public static func == (lhs: BaseImage, rhs: BaseImage) -> Bool { lhs === rhs }
}

/// Everything the editor can undo: the base image (changed by crop and merge) plus its annotations.
/// Immutable, so `UndoHistory<EditorState>` gives whole-editor undo/redo.
public struct EditorState: Equatable, Sendable {
    public let baseImage: BaseImage
    public let document: AnnotationDocument

    /// `pointScale` is image pixels per document point (2 for a Retina capture).
    public init(image: CGImage, pointScale: CGFloat = 1) {
        let scale = pointScale > 0 ? pointScale : 1
        baseImage = BaseImage(image)
        document = AnnotationDocument(canvasSize: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale))
    }

    private init(baseImage: BaseImage, document: AnnotationDocument) {
        self.baseImage = baseImage
        self.document = document
    }

    public var pointScale: CGFloat {
        document.canvasSize.width > 0 ? CGFloat(baseImage.cgImage.width) / document.canvasSize.width : 1
    }

    public func with(document: AnnotationDocument) -> EditorState {
        EditorState(baseImage: baseImage, document: document)
    }

    /// Crops the image and canvas to `rect` (document points, clamped to the canvas, snapped to whole pixels).
    /// Annotations shift with it. Nil when `rect` doesn't overlap the canvas.
    public func cropped(to rect: CGRect) -> EditorState? {
        let scale = pointScale
        let image = baseImage.cgImage
        let clamped = rect.intersection(CGRect(origin: .zero, size: document.canvasSize))
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return nil }

        let pixelRect = CGRect(x: clamped.minX * scale, y: clamped.minY * scale, width: clamped.width * scale, height: clamped.height * scale)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !pixelRect.isNull, pixelRect.width >= 1, pixelRect.height >= 1, let result = image.cropping(to: pixelRect) else { return nil }

        let pointRect = CGRect(x: pixelRect.minX / scale, y: pixelRect.minY / scale, width: pixelRect.width / scale, height: pixelRect.height / scale)
        return EditorState(baseImage: BaseImage(result), document: document.cropped(to: pointRect))
    }

    /// The Merge tool: adds `other` to the right of the current image, e.g. to stitch two screenshots side by side.
    /// Existing annotations keep their positions.
    public func appendingRight(_ other: CGImage) -> EditorState? {
        guard let combined = ImageOperations.appendingRight(baseImage.cgImage, other) else { return nil }
        let scale = pointScale
        let canvas = CGSize(width: CGFloat(combined.width) / scale, height: CGFloat(combined.height) / scale)
        return EditorState(
            baseImage: BaseImage(combined),
            document: AnnotationDocument(canvasSize: canvas, annotations: document.annotations)
        )
    }

    /// The final image with annotations baked in (and pixelate applied irreversibly).
    public func flattened() -> CGImage? {
        AnnotationRenderer.flatten(baseImage.cgImage, with: document)
    }
}
