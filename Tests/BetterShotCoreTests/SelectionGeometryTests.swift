import CoreGraphics
import Testing
@testable import BetterShotCore

struct SelectionGeometryTests {
    @Test func rectFromDragNormalizesAnyDirection() {
        let expected = CGRect(x: 10, y: 20, width: 30, height: 40)
        #expect(SelectionGeometry.rect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 60)) == expected)
        #expect(SelectionGeometry.rect(from: CGPoint(x: 40, y: 60), to: CGPoint(x: 10, y: 20)) == expected)
        #expect(SelectionGeometry.rect(from: CGPoint(x: 40, y: 20), to: CGPoint(x: 10, y: 60)) == expected)
    }

    @Test func rectFromDragSnapsToWholePoints() {
        let rect = SelectionGeometry.rect(from: CGPoint(x: 10.4, y: 20.6), to: CGPoint(x: 40.2, y: 60.9))
        #expect(rect == CGRect(x: 10, y: 21, width: 30, height: 40))
    }

    @Test func movedShiftsRectKeepingSize() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let moved = SelectionGeometry.moved(CGRect(x: 100, y: 100, width: 50, height: 60), by: CGSize(width: 5, height: -10), within: bounds)
        #expect(moved == CGRect(x: 105, y: 90, width: 50, height: 60))
    }

    @Test func movedStaysInsideBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let rect = CGRect(x: 150, y: 10, width: 50, height: 50)
        let moved = SelectionGeometry.moved(rect, by: CGSize(width: 40, height: -40), within: bounds)
        #expect(moved == CGRect(x: 150, y: 0, width: 50, height: 50))
    }

    @Test func clampedCropsToBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(SelectionGeometry.clamped(CGRect(x: -10, y: 90, width: 50, height: 50), to: bounds) == CGRect(x: 0, y: 90, width: 40, height: 10))
    }

    @Test func tinySelectionsAreNotUsable() {
        #expect(!SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 0, height: 50)))
        #expect(!SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 50, height: 2)))
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 5, height: 5)))
    }

    @Test func flipsGlobalAppKitRectIntoDisplayLocalTopLeftSpace() {
        // Secondary display to the right, 1920x1080, origin (1440, 0) in AppKit space.
        let screen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        // 100x50 rect whose bottom-left is 10pt from the screen's left and 20pt from the bottom.
        let global = CGRect(x: 1450, y: 20, width: 100, height: 50)
        #expect(SelectionGeometry.displayLocalRect(fromGlobal: global, screenFrame: screen) == CGRect(x: 10, y: 1010, width: 100, height: 50))
    }

    @Test func convertsWindowListBoundsToAppKitSpace() {
        // CGWindowList uses a top-left origin on the primary display (height 900).
        let bounds = CGRect(x: 100, y: 50, width: 400, height: 300)
        #expect(SelectionGeometry.appKitRect(fromWindowListBounds: bounds, primaryScreenHeight: 900) == CGRect(x: 100, y: 550, width: 400, height: 300))
    }
}
