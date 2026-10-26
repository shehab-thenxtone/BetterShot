import CoreGraphics
import Testing
@testable import BetterShotAnnotations

struct AnnotationHistoryTests {
    private let empty = AnnotationDocument(canvasSize: CGSize(width: 100, height: 100))
    private let style = AnnotationStyle()

    private func box(_ x: CGFloat) -> AnnotationKind {
        .rectangle(CGRect(x: x, y: 0, width: 10, height: 10), isFilled: false)
    }

    @Test func startsWithNothingToUndoOrRedo() {
        let history = AnnotationHistory(initial: empty)
        #expect(!history.canUndo)
        #expect(!history.canRedo)
        #expect(history.present == empty)
    }

    @Test func undoAndRedoStepOneAnnotationAtATime() {
        let one = empty.adding(box(0), style: style)
        let two = one.adding(box(20), style: style)
        let history = AnnotationHistory(initial: empty).committing(one).committing(two)

        #expect(history.present == two)
        #expect(history.undone().present == one)
        #expect(history.undone().undone().present == empty)
        #expect(history.undone().undone().redone().present == one)
        #expect(history.undone().redone().present == two)
    }

    @Test func committingAfterUndoDiscardsTheRedoBranch() {
        let one = empty.adding(box(0), style: style)
        let alternative = empty.adding(box(50), style: style)
        let history = AnnotationHistory(initial: empty).committing(one).undone().committing(alternative)

        #expect(history.present == alternative)
        #expect(!history.canRedo)
    }

    @Test func committingAnUnchangedDocumentIsANoOp() {
        let history = AnnotationHistory(initial: empty)
        #expect(history.committing(empty) == history)
    }

    @Test func undoOrRedoWithNothingToDoReturnsTheSameHistory() {
        let history = AnnotationHistory(initial: empty)
        #expect(history.undone() == history)
        #expect(history.redone() == history)
    }

    @Test func historyWorksForAnyEquatableState() {
        let history = UndoHistory(initial: 1).committing(2).committing(3)
        #expect(history.present == 3)
        #expect(history.undone().undone().present == 1)
        #expect(history.undone().redone().present == 3)
    }

    @Test func undoDepthIsCapped() {
        var history = AnnotationHistory(initial: empty)
        var document = empty
        for index in 0..<(AnnotationHistory.maxUndoSteps + 50) {
            document = document.adding(box(CGFloat(index)), style: style)
            history = history.committing(document)
        }
        #expect(history.undoDepth == AnnotationHistory.maxUndoSteps)
        #expect(history.present == document)
    }
}
