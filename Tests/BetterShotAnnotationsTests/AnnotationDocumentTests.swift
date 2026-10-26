import CoreGraphics
import Foundation
import Testing
@testable import BetterShotAnnotations

struct AnnotationDocumentTests {
    private let canvas = CGSize(width: 200, height: 100)
    private let style = AnnotationStyle()

    private func makeDocument() -> AnnotationDocument {
        AnnotationDocument(canvasSize: canvas)
    }

    private func box(_ x: CGFloat, _ y: CGFloat) -> AnnotationKind {
        .rectangle(CGRect(x: x, y: y, width: 20, height: 20), isFilled: true)
    }

    @Test func addingAppendsOnTopAndLeavesOriginalUntouched() {
        let original = makeDocument()
        let first = original.adding(box(0, 0), style: style)
        let second = first.adding(box(10, 10), style: style)

        #expect(original.annotations.isEmpty)
        #expect(first.annotations.count == 1)
        #expect(second.annotations.count == 2)
        #expect(second.annotations[0].id == first.annotations[0].id)
        #expect(second.annotations[1].id != second.annotations[0].id)
    }

    @Test func removingDeletesOnlyTheGivenAnnotation() {
        let doc = makeDocument().adding(box(0, 0), style: style).adding(box(50, 0), style: style)
        let removed = doc.removing(id: doc.annotations[0].id)
        #expect(removed.annotations.map(\.id) == [doc.annotations[1].id])
    }

    @Test func replacingKindRestylingMovingAndResizingChangeOnlyTheTarget() {
        let doc = makeDocument().adding(box(0, 0), style: style).adding(box(50, 0), style: style)
        let target = doc.annotations[0].id
        let other = doc.annotations[1]

        let replaced = doc.replacingKind(of: target, with: .ellipse(CGRect(x: 1, y: 1, width: 5, height: 5)))
        #expect(replaced.annotation(id: target)?.kind == .ellipse(CGRect(x: 1, y: 1, width: 5, height: 5)))

        let newStyle = style.updating(color: .azure, lineWeight: .thick)
        let restyled = doc.restyling(id: target, with: newStyle)
        #expect(restyled.annotation(id: target)?.style == newStyle)

        let moved = doc.moving(id: target, by: CGSize(width: 5, height: 7))
        #expect(moved.annotation(id: target)?.kind == .rectangle(CGRect(x: 5, y: 7, width: 20, height: 20), isFilled: true))

        let resized = doc.resizing(id: target, to: CGRect(x: 0, y: 0, width: 40, height: 10))
        #expect(resized.annotation(id: target)?.kind == .rectangle(CGRect(x: 0, y: 0, width: 40, height: 10), isFilled: true))

        for changed in [replaced, restyled, moved, resized] {
            #expect(changed.annotation(id: other.id) == other)
        }
    }

    @Test func editingAnUnknownIdChangesNothing() {
        let doc = makeDocument().adding(box(0, 0), style: style)
        let missing = UUID()
        #expect(doc.removing(id: missing) == doc)
        #expect(doc.moving(id: missing, by: CGSize(width: 1, height: 1)) == doc)
        #expect(doc.restyling(id: missing, with: style.updating(color: .azure)) == doc)
    }

    @Test func stepNumbersStartAtOneAndIncrement() {
        var doc = makeDocument()
        #expect(doc.nextStepNumber == 1)

        doc = doc.addingStep(at: CGPoint(x: 10, y: 10), style: style)
        doc = doc.addingStep(at: CGPoint(x: 40, y: 10), style: style)
        #expect(doc.annotations.map(\.kind) == [
            .stepCounter(center: CGPoint(x: 10, y: 10), number: 1),
            .stepCounter(center: CGPoint(x: 40, y: 10), number: 2),
        ])
        #expect(doc.nextStepNumber == 3)
    }

    @Test func stepNumberFollowsTheHighestExistingStep() {
        var doc = makeDocument()
        doc = doc.addingStep(at: .zero, style: style).addingStep(at: .zero, style: style)
        #expect(doc.removing(id: doc.annotations[0].id).nextStepNumber == 3)
        #expect(doc.removing(id: doc.annotations[1].id).nextStepNumber == 2)
    }

    @Test func topmostAnnotationIsTheLastOneUnderThePoint() {
        let doc = makeDocument().adding(box(0, 0), style: style).adding(box(10, 10), style: style)
        #expect(doc.topmostAnnotation(at: CGPoint(x: 15, y: 15), tolerance: 0)?.id == doc.annotations[1].id)
        #expect(doc.topmostAnnotation(at: CGPoint(x: 2, y: 2), tolerance: 0)?.id == doc.annotations[0].id)
        #expect(doc.topmostAnnotation(at: CGPoint(x: 150, y: 90), tolerance: 0) == nil)
    }

    @Test func croppingShiftsAnnotationsAndShrinksTheCanvas() {
        let doc = makeDocument().adding(box(50, 30), style: style)
        let cropped = doc.cropped(to: CGRect(x: 40, y: 20, width: 100, height: 60))
        #expect(cropped.canvasSize == CGSize(width: 100, height: 60))
        #expect(cropped.annotations[0].kind == .rectangle(CGRect(x: 10, y: 10, width: 20, height: 20), isFilled: true))
    }

    @Test func croppingBeyondTheCanvasIsClamped() {
        let cropped = makeDocument().cropped(to: CGRect(x: 150, y: 50, width: 500, height: 500))
        #expect(cropped.canvasSize == CGSize(width: 50, height: 50))
    }

    @Test func croppingOutsideTheCanvasLeavesTheDocumentUnchanged() {
        let doc = makeDocument().adding(box(0, 0), style: style)
        #expect(doc.cropped(to: CGRect(x: 500, y: 500, width: 10, height: 10)) == doc)
    }
}
