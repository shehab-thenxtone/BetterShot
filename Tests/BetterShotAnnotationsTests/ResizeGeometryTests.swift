import CoreGraphics
import Testing
@testable import BetterShotAnnotations

struct ResizeGeometryTests {
    private let rect = CGRect(x: 10, y: 10, width: 100, height: 50)

    @Test func handlePositionsSitOnCornersAndEdgeMidpoints() {
        let positions = ResizeGeometry.handlePositions(of: CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(positions[.topLeft] == CGPoint(x: 0, y: 0))
        #expect(positions[.top] == CGPoint(x: 50, y: 0))
        #expect(positions[.bottomRight] == CGPoint(x: 100, y: 50))
        #expect(positions[.left] == CGPoint(x: 0, y: 25))
        #expect(positions.count == 8)
    }

    @Test func handleHitTestFindsTheNearestHandleWithinTolerance() {
        let box = CGRect(x: 0, y: 0, width: 100, height: 50)
        #expect(ResizeGeometry.handle(at: CGPoint(x: 1, y: 1), of: box, tolerance: 6) == .topLeft)
        #expect(ResizeGeometry.handle(at: CGPoint(x: 50, y: 1), of: box, tolerance: 6) == .top)
        #expect(ResizeGeometry.handle(at: CGPoint(x: 99, y: 49), of: box, tolerance: 6) == .bottomRight)
        #expect(ResizeGeometry.handle(at: CGPoint(x: 50, y: 25), of: box, tolerance: 6) == nil)
    }

    @Test func draggingAnEdgeMovesOnlyThatEdge() {
        #expect(ResizeGeometry.resize(rect, dragging: .right, to: CGPoint(x: 150, y: 999)) == CGRect(x: 10, y: 10, width: 140, height: 50))
        #expect(ResizeGeometry.resize(rect, dragging: .top, to: CGPoint(x: 999, y: 0)) == CGRect(x: 10, y: 0, width: 100, height: 60))
    }

    @Test func draggingACornerMovesBothAdjacentEdges() {
        #expect(ResizeGeometry.resize(rect, dragging: .topLeft, to: CGPoint(x: 0, y: 0)) == CGRect(x: 0, y: 0, width: 110, height: 60))
        #expect(ResizeGeometry.resize(rect, dragging: .bottomRight, to: CGPoint(x: 200, y: 100)) == CGRect(x: 10, y: 10, width: 190, height: 90))
    }

    @Test func draggingPastTheOppositeEdgeStopsAtTheMinimumSide() {
        let resized = ResizeGeometry.resize(rect, dragging: .right, to: CGPoint(x: 5, y: 0), minimumSide: 8)
        #expect(resized == CGRect(x: 10, y: 10, width: 8, height: 50))
    }

    @Test func resizeStaysInsideBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let resized = ResizeGeometry.resize(rect, dragging: .bottomRight, to: CGPoint(x: 500, y: 500), within: bounds)
        #expect(resized == CGRect(x: 10, y: 10, width: 190, height: 190))
    }

    @Test func cornerDragKeepsTheAspectRatio() {
        let box = CGRect(x: 0, y: 0, width: 100, height: 50)
        let resized = ResizeGeometry.resize(box, dragging: .bottomRight, to: CGPoint(x: 60, y: 100), aspectRatio: 1)
        #expect(resized == CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    @Test func topLeftCornerKeepsTheOppositeCornerFixedWhenConstrained() {
        let box = CGRect(x: 50, y: 50, width: 50, height: 50)
        let resized = ResizeGeometry.resize(box, dragging: .topLeft, to: CGPoint(x: 0, y: 20), aspectRatio: 1)
        #expect(resized == CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    @Test func constrainedResizeShrinksToFitInsideBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        let resized = ResizeGeometry.resize(CGRect(x: 0, y: 0, width: 10, height: 10), dragging: .bottomRight,
                                            to: CGPoint(x: 200, y: 100), aspectRatio: 1, within: bounds)
        #expect(resized == CGRect(x: 0, y: 0, width: 80, height: 80))
    }

    @Test func edgeDragWithAspectRatioAdjustsTheOtherSideAroundTheCentre() {
        let box = CGRect(x: 0, y: 0, width: 100, height: 50) // 2:1
        let resized = ResizeGeometry.resize(box, dragging: .bottom, to: CGPoint(x: 0, y: 100), aspectRatio: 2)
        #expect(resized == CGRect(x: -50, y: 0, width: 200, height: 100))
    }
}
