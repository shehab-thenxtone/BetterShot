import CoreGraphics
import Testing
@testable import BetterShotAnnotations

struct ShapeGestureTests {
    private let origin = CGPoint(x: 0, y: 0)

    @Test func rectangleToolsNormalizeTheDragAcrossDirections() {
        let expected = CGRect(x: 10, y: 20, width: 30, height: 40)
        #expect(ShapeGesture.kind(for: .rectangle, from: CGPoint(x: 40, y: 60), to: CGPoint(x: 10, y: 20), constrained: false)
            == .rectangle(expected, isFilled: false))
        #expect(ShapeGesture.kind(for: .filledRectangle, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 60), constrained: false)
            == .rectangle(expected, isFilled: true))
        #expect(ShapeGesture.kind(for: .ellipse, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 60), constrained: false)
            == .ellipse(expected))
    }

    @Test func shiftMakesShapesSquareInTheDragDirection() {
        #expect(ShapeGesture.kind(for: .rectangle, from: origin, to: CGPoint(x: 30, y: 10), constrained: true)
            == .rectangle(CGRect(x: 0, y: 0, width: 30, height: 30), isFilled: false))
        #expect(ShapeGesture.kind(for: .ellipse, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 20, y: 45), constrained: true)
            == .ellipse(CGRect(x: 20, y: 20, width: 30, height: 30)))
    }

    @Test func tinyShapesAreRejectedSoClicksDontCreateThem() {
        #expect(ShapeGesture.kind(for: .rectangle, from: origin, to: CGPoint(x: 1, y: 1), constrained: false) == nil)
        #expect(ShapeGesture.kind(for: .pixelate, from: origin, to: CGPoint(x: 2, y: 30), constrained: false) == nil)
        #expect(ShapeGesture.kind(for: .line, from: origin, to: CGPoint(x: 1, y: 1), constrained: false) == nil)
    }

    @Test func pixelateAndTextHighlightMakeRegions() {
        let end = CGPoint(x: 40, y: 30)
        #expect(ShapeGesture.kind(for: .pixelate, from: origin, to: end, constrained: false) == .pixelate(CGRect(x: 0, y: 0, width: 40, height: 30)))
        #expect(ShapeGesture.kind(for: .textHighlighter, from: origin, to: end, constrained: false) == .textHighlight(CGRect(x: 0, y: 0, width: 40, height: 30)))
    }

    @Test func linesAndArrowsKeepTheirEndpoints() {
        let end = CGPoint(x: 40, y: 13)
        #expect(ShapeGesture.kind(for: .line, from: origin, to: end, constrained: false) == .line(from: origin, to: end))
        #expect(ShapeGesture.kind(for: .arrow, from: origin, to: end, constrained: false) == .arrow(from: origin, to: end))
    }

    @Test func shiftSnapsLinesToMultiplesOfFortyFiveDegrees() throws {
        let nearHorizontal = try #require(ShapeGesture.kind(for: .line, from: origin, to: CGPoint(x: 100, y: 5), constrained: true))
        guard case .line(_, let flatEnd) = nearHorizontal else { Issue.record("expected a line"); return }
        #expect(abs(flatEnd.y) < 1e-9)
        #expect(abs(flatEnd.x - hypot(100, 5)) < 1e-9) // length is preserved

        let nearDiagonal = try #require(ShapeGesture.kind(for: .arrow, from: origin, to: CGPoint(x: 100, y: 90), constrained: true))
        guard case .arrow(_, let diagonalEnd) = nearDiagonal else { Issue.record("expected an arrow"); return }
        #expect(abs(diagonalEnd.x - diagonalEnd.y) < 1e-9)
    }

    @Test func toolsThatAreNotDragShapesProduceNothing() {
        for tool in [AnnotationTool.select, .text, .stepCounter, .pen, .marker] {
            #expect(ShapeGesture.kind(for: tool, from: origin, to: CGPoint(x: 50, y: 50), constrained: false) == nil)
        }
    }
}
