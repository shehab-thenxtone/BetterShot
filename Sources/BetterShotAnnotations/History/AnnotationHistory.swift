/// Undo/redo over whole-document snapshots. Because documents are immutable values, each committed edit is
/// one cheap snapshot and undo is just stepping back, at annotation granularity (requirements §3.3).
public struct AnnotationHistory: Equatable, Sendable {
    public static let maxUndoSteps = 100

    public let present: AnnotationDocument
    private let past: [AnnotationDocument]
    private let future: [AnnotationDocument]

    public init(initial: AnnotationDocument) {
        self.init(present: initial, past: [], future: [])
    }

    private init(present: AnnotationDocument, past: [AnnotationDocument], future: [AnnotationDocument]) {
        self.present = present
        self.past = past
        self.future = future
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public var undoDepth: Int { past.count }

    /// Records `document` as the new present. Unchanged documents are ignored; any redo branch is dropped.
    public func committing(_ document: AnnotationDocument) -> AnnotationHistory {
        guard document != present else { return self }
        var newPast = past + [present]
        if newPast.count > Self.maxUndoSteps {
            newPast.removeFirst(newPast.count - Self.maxUndoSteps)
        }
        return AnnotationHistory(present: document, past: newPast, future: [])
    }

    public func undone() -> AnnotationHistory {
        guard let previous = past.last else { return self }
        return AnnotationHistory(present: previous, past: Array(past.dropLast()), future: [present] + future)
    }

    public func redone() -> AnnotationHistory {
        guard let next = future.first else { return self }
        return AnnotationHistory(present: next, past: past + [present], future: Array(future.dropFirst()))
    }
}
