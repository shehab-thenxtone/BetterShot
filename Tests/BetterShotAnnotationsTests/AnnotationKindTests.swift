import CoreGraphics
import Testing
@testable import BetterShotAnnotations

struct AnnotationKindTests {
    @Test func rectangleAndEllipseBoundsAreTheirRects() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        #expect(AnnotationKind.rectangle(rect, isFilled: false).bounds == rect)
        #expect(AnnotationKind.ellipse(rect).bounds == rect)
        #expect(AnnotationKind.pixelate(rect).bounds == rect)
        #expect(AnnotationKind.textHighlight(rect).bounds == rect)
    }

    @Test func lineBoundsAreNormalizedRegardlessOfDirection() {
        let line = AnnotationKind.line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 2, y: 30))
        #expect(line.bounds == CGRect(x: 2, y: 10, width: 8, height: 20))
    }

    @Test func stepCounterBoundsAreACircleAroundItsCenter() {
        let step = AnnotationKind.stepCounter(center: CGPoint(x: 50, y: 50), number: 3)
        #expect(step.bounds == CGRect(x: 36, y: 36, width: 28, height: 28))
    }

    @Test func freehandBoundsEncloseAllPoints() {
        let pen = AnnotationKind.pen(points: [CGPoint(x: 5, y: 9), CGPoint(x: 20, y: 2), CGPoint(x: 12, y: 30)])
        #expect(pen.bounds == CGRect(x: 5, y: 2, width: 15, height: 28))
        #expect(AnnotationKind.marker(points: []).bounds == .zero)
    }

    @Test func textBoundsStartAtOriginAndGrowWithFontSize() {
        let small = AnnotationKind.text("Hello", origin: CGPoint(x: 10, y: 20), fontSize: 12).bounds
        let large = AnnotationKind.text("Hello", origin: CGPoint(x: 10, y: 20), fontSize: 24).bounds
        #expect(small.origin == CGPoint(x: 10, y: 20))
        #expect(small.width > 0 && small.height > 0)
        #expect(large.width > small.width && large.height > small.height)
    }

    @Test func multilineTextIsTallerThanSingleLine() {
        let one = AnnotationKind.text("Hi", origin: .zero, fontSize: 16).bounds
        let two = AnnotationKind.text("Hi\nthere", origin: .zero, fontSize: 16).bounds
        #expect(two.height > one.height * 1.5)
    }

    @Test func lineHitTestUsesDistanceToTheSegment() {
        let line = AnnotationKind.line(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0))
        #expect(line.contains(CGPoint(x: 50, y: 2), tolerance: 3))
        #expect(!line.contains(CGPoint(x: 50, y: 10), tolerance: 3))
        #expect(!line.contains(CGPoint(x: 120, y: 0), tolerance: 3))
    }

    @Test func rectangleHitTestUsesBoundsPlusTolerance() {
        let rect = AnnotationKind.rectangle(CGRect(x: 10, y: 10, width: 20, height: 20), isFilled: true)
        #expect(rect.contains(CGPoint(x: 20, y: 20), tolerance: 0))
        #expect(rect.contains(CGPoint(x: 8, y: 20), tolerance: 3))
        #expect(!rect.contains(CGPoint(x: 0, y: 20), tolerance: 3))
    }

    @Test func transformMapsGeometryBetweenRects() {
        let old = CGRect(x: 0, y: 0, width: 10, height: 10)
        let new = CGRect(x: 0, y: 0, width: 20, height: 40)

        let rect = AnnotationKind.rectangle(CGRect(x: 2, y: 2, width: 4, height: 4), isFilled: false)
        #expect(rect.transformed(from: old, to: new) == .rectangle(CGRect(x: 4, y: 8, width: 8, height: 16), isFilled: false))

        let line = AnnotationKind.line(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 10, y: 10))
        #expect(line.transformed(from: old, to: new) == .line(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 20, y: 40)))
    }

    @Test func transformScalesTextByHeightRatio() {
        let old = CGRect(x: 0, y: 0, width: 10, height: 10)
        let new = CGRect(x: 5, y: 5, width: 10, height: 20)
        let text = AnnotationKind.text("A", origin: CGPoint(x: 0, y: 0), fontSize: 10)
        #expect(text.transformed(from: old, to: new) == .text("A", origin: CGPoint(x: 5, y: 5), fontSize: 20))
    }

    @Test func transformFromEmptyRectDoesNotDivideByZero() {
        let line = AnnotationKind.line(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5))
        let moved = line.transformed(from: CGRect(x: 5, y: 5, width: 0, height: 0), to: CGRect(x: 10, y: 10, width: 0, height: 0))
        #expect(moved == .line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 10)))
    }

    @Test func translatedShiftsEveryPoint() {
        let arrow = AnnotationKind.arrow(from: CGPoint(x: 1, y: 2), to: CGPoint(x: 3, y: 4))
        #expect(arrow.translated(by: CGSize(width: 10, height: -1)) == .arrow(from: CGPoint(x: 11, y: 1), to: CGPoint(x: 13, y: 3)))

        let step = AnnotationKind.stepCounter(center: CGPoint(x: 5, y: 5), number: 2)
        #expect(step.translated(by: CGSize(width: 1, height: 1)) == .stepCounter(center: CGPoint(x: 6, y: 6), number: 2))
    }
}
