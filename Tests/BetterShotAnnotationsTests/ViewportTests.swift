import CoreGraphics
import Testing
@testable import BetterShotAnnotations

struct ViewportTests {
    @Test func smallCanvasIsCentredAtActualSize() {
        let viewport = Viewport(canvasSize: CGSize(width: 200, height: 100), viewSize: CGSize(width: 400, height: 400))
        #expect(viewport.scale == 1)
        #expect(viewport.origin == CGPoint(x: 100, y: 150))
    }

    @Test func largeCanvasScalesDownToFit() {
        let viewport = Viewport(canvasSize: CGSize(width: 800, height: 400), viewSize: CGSize(width: 400, height: 400))
        #expect(viewport.scale == 0.5)
        #expect(viewport.origin == CGPoint(x: 0, y: 100))
    }

    @Test func paddingShrinksTheAvailableArea() {
        let viewport = Viewport(canvasSize: CGSize(width: 400, height: 400), viewSize: CGSize(width: 400, height: 400), padding: 20)
        #expect(viewport.scale == 0.9)
        #expect(viewport.origin == CGPoint(x: 20, y: 20))
    }

    @Test func convertsBetweenViewAndCanvasCoordinates() {
        let viewport = Viewport(canvasSize: CGSize(width: 800, height: 400), viewSize: CGSize(width: 400, height: 400))
        #expect(viewport.toCanvas(CGPoint(x: 200, y: 200)) == CGPoint(x: 400, y: 200)) // centre maps to centre
        #expect(viewport.toView(CGPoint(x: 0, y: 0)) == CGPoint(x: 0, y: 100))

        let point = CGPoint(x: 123, y: 321)
        let roundTrip = viewport.toCanvas(viewport.toView(point))
        #expect(abs(roundTrip.x - point.x) < 1e-9 && abs(roundTrip.y - point.y) < 1e-9)
    }

    @Test func canvasRectInViewIsTheScaledAndOffsetCanvas() {
        let viewport = Viewport(canvasSize: CGSize(width: 800, height: 400), viewSize: CGSize(width: 400, height: 400))
        #expect(viewport.canvasRectInView == CGRect(x: 0, y: 100, width: 400, height: 200))
    }

    @Test func degenerateSizesDoNotCrashOrDivideByZero() {
        let viewport = Viewport(canvasSize: .zero, viewSize: CGSize(width: 100, height: 100))
        #expect(viewport.scale == 1)
        #expect(viewport.toCanvas(CGPoint(x: 5, y: 5)) == CGPoint(x: 5, y: 5))
    }
}
