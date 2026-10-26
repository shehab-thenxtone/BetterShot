/// Undo/redo over whole-state snapshots. Because states are immutable values, each committed edit is one
/// cheap snapshot and undo is just stepping back, at annotation granularity (requirements §3.3).
public struct UndoHistory<State: Equatable & Sendable>: Equatable, Sendable {
    public static var maxUndoSteps: Int { 100 }

    public let present: State
    private let past: [State]
    private let future: [State]

    public init(initial: State) {
        self.init(present: initial, past: [], future: [])
    }

    private init(present: State, past: [State], future: [State]) {
        self.present = present
        self.past = past
        self.future = future
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public var undoDepth: Int { past.count }

    /// Records `state` as the new present. Unchanged states are ignored; any redo branch is dropped.
    public func committing(_ state: State) -> UndoHistory {
        guard state != present else { return self }
        var newPast = past + [present]
        if newPast.count > Self.maxUndoSteps {
            newPast.removeFirst(newPast.count - Self.maxUndoSteps)
        }
        return UndoHistory(present: state, past: newPast, future: [])
    }

    public func undone() -> UndoHistory {
        guard let previous = past.last else { return self }
        return UndoHistory(present: previous, past: Array(past.dropLast()), future: [present] + future)
    }

    public func redone() -> UndoHistory {
        guard let next = future.first else { return self }
        return UndoHistory(present: next, past: past + [present], future: Array(future.dropFirst()))
    }
}

/// History of an annotation document alone.
public typealias AnnotationHistory = UndoHistory<AnnotationDocument>
