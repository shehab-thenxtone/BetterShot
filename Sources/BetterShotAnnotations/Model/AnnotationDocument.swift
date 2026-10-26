import CoreGraphics
import Foundation

public struct Annotation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: AnnotationKind
    public let style: AnnotationStyle

    public init(id: UUID = UUID(), kind: AnnotationKind, style: AnnotationStyle) {
        self.id = id
        self.kind = kind
        self.style = style
    }
}

/// Everything drawn over one captured image, back to front. Coordinates are points with a top-left origin;
/// `canvasSize` is the image's size in those points. Immutable: every edit returns a new document, which is
/// what makes per-annotation undo/redo and non-destructive editing straightforward (requirements §3.3).
public struct AnnotationDocument: Equatable, Sendable {
    public let canvasSize: CGSize
    public let annotations: [Annotation]

    public init(canvasSize: CGSize, annotations: [Annotation] = []) {
        self.canvasSize = canvasSize
        self.annotations = annotations
    }

    public func annotation(id: UUID) -> Annotation? {
        annotations.first { $0.id == id }
    }

    // MARK: Adding and removing

    public func adding(_ kind: AnnotationKind, style: AnnotationStyle, id: UUID = UUID()) -> AnnotationDocument {
        AnnotationDocument(canvasSize: canvasSize, annotations: annotations + [Annotation(id: id, kind: kind, style: style)])
    }

    /// Adds several annotations in one edit, so they are a single undo step (e.g. one snapped highlight per text line).
    public func adding(contentsOf kinds: [AnnotationKind], style: AnnotationStyle) -> AnnotationDocument {
        guard !kinds.isEmpty else { return self }
        return AnnotationDocument(
            canvasSize: canvasSize,
            annotations: annotations + kinds.map { Annotation(kind: $0, style: style) }
        )
    }

    public func removing(id: UUID) -> AnnotationDocument {
        AnnotationDocument(canvasSize: canvasSize, annotations: annotations.filter { $0.id != id })
    }

    // MARK: Editing one annotation (unknown ids change nothing)

    public func replacingKind(of id: UUID, with kind: AnnotationKind) -> AnnotationDocument {
        mapping(id) { Annotation(id: $0.id, kind: kind, style: $0.style) }
    }

    public func restyling(id: UUID, with style: AnnotationStyle) -> AnnotationDocument {
        mapping(id) { Annotation(id: $0.id, kind: $0.kind, style: style) }
    }

    public func moving(id: UUID, by delta: CGSize) -> AnnotationDocument {
        mapping(id) { Annotation(id: $0.id, kind: $0.kind.translated(by: delta), style: $0.style) }
    }

    /// Resizes the annotation so its bounds become `newBounds` (drag handles in the editor).
    public func resizing(id: UUID, to newBounds: CGRect) -> AnnotationDocument {
        mapping(id) { Annotation(id: $0.id, kind: $0.kind.transformed(from: $0.kind.bounds, to: newBounds), style: $0.style) }
    }

    // MARK: Step counter

    /// Step badges auto-increment from the highest number already placed.
    public var nextStepNumber: Int {
        let highest = annotations.compactMap { annotation -> Int? in
            if case .stepCounter(_, let number) = annotation.kind { number } else { nil }
        }.max() ?? 0
        return highest + 1
    }

    public func addingStep(at center: CGPoint, style: AnnotationStyle) -> AnnotationDocument {
        adding(.stepCounter(center: center, number: nextStepNumber), style: style)
    }

    // MARK: Selection and cropping

    /// The front-most annotation under `point`, for the selection tool.
    public func topmostAnnotation(at point: CGPoint, tolerance: CGFloat) -> Annotation? {
        annotations.last { $0.kind.contains(point, tolerance: tolerance) }
    }

    /// Crops the canvas to `rect` (clamped to the canvas) and shifts annotations to the new origin.
    /// Annotations that fall outside are kept; the renderer clips them.
    public func cropped(to rect: CGRect) -> AnnotationDocument {
        let clamped = rect.intersection(CGRect(origin: .zero, size: canvasSize))
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return self }
        let shift = CGSize(width: -clamped.minX, height: -clamped.minY)
        return AnnotationDocument(
            canvasSize: clamped.size,
            annotations: annotations.map { Annotation(id: $0.id, kind: $0.kind.translated(by: shift), style: $0.style) }
        )
    }

    // MARK: Private

    private func mapping(_ id: UUID, _ transform: (Annotation) -> Annotation) -> AnnotationDocument {
        AnnotationDocument(canvasSize: canvasSize, annotations: annotations.map { $0.id == id ? transform($0) : $0 })
    }
}
