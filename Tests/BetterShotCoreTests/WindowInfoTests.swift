import CoreGraphics
import Testing
@testable import BetterShotCore

struct WindowInfoTests {
    private let back = WindowInfo(id: 1, ownerName: "Back", frame: CGRect(x: 0, y: 0, width: 500, height: 500))
    private let front = WindowInfo(id: 2, ownerName: "Front", frame: CGRect(x: 100, y: 100, width: 200, height: 200))

    @Test func topmostReturnsFirstWindowContainingPointInFrontToBackOrder() {
        #expect(WindowInfo.topmost(at: CGPoint(x: 150, y: 150), in: [front, back])?.id == 2)
    }

    @Test func topmostFallsThroughToWindowBehind() {
        #expect(WindowInfo.topmost(at: CGPoint(x: 10, y: 10), in: [front, back])?.id == 1)
    }

    @Test func topmostIsNilWhenNothingContainsPoint() {
        #expect(WindowInfo.topmost(at: CGPoint(x: 900, y: 900), in: [front, back]) == nil)
    }
}
