import CoreGraphics
import Testing
@testable import BetterShotCore

struct WindowPlacementTests {
    private let maximum = CGSize(width: 800, height: 600)

    @Test func smallImagesKeepTheirSize() {
        #expect(PinPlacement.fittedSize(for: CGSize(width: 400, height: 300), within: maximum) == CGSize(width: 400, height: 300))
    }

    @Test func largeImagesShrinkToFitKeepingTheirAspectRatio() {
        #expect(PinPlacement.fittedSize(for: CGSize(width: 2000, height: 1000), within: maximum) == CGSize(width: 800, height: 400))
    }

    @Test func tinyImagesGrowToTheMinimumSide() {
        #expect(PinPlacement.fittedSize(for: CGSize(width: 20, height: 10), within: maximum, minimumSide: 80) == CGSize(width: 160, height: 80))
    }

    @Test func theMaximumWinsOverTheMinimumForExtremeAspectRatios() {
        let size = PinPlacement.fittedSize(for: CGSize(width: 4000, height: 10), within: maximum, minimumSide: 80)
        #expect(size.width == 800)
        #expect(size.height == 2)
    }

    @Test func emptyImagesGetAUsableSquare() {
        #expect(PinPlacement.fittedSize(for: .zero, within: maximum, minimumSide: 80) == CGSize(width: 80, height: 80))
    }

    @Test func newPinsCascadeDownAndRightThenWrap() {
        #expect(PinPlacement.cascadeOffset(forIndex: 0) == .zero)
        #expect(PinPlacement.cascadeOffset(forIndex: 1) == CGSize(width: 28, height: -28))
        #expect(PinPlacement.cascadeOffset(forIndex: 8) == .zero)
    }

    @Test func dockedBarSitsCentredAboveTheBottomEdge() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 875) // below the menu bar, above the Dock
        let origin = DockPlacement.bottomCenter(size: CGSize(width: 400, height: 52), in: visible, margin: 16)
        #expect(origin == CGPoint(x: 520, y: 41))
    }

    @Test func dockedBarOnASecondaryDisplayUsesThatDisplaysFrame() {
        let visible = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let origin = DockPlacement.bottomCenter(size: CGSize(width: 400, height: 52), in: visible, margin: 16)
        #expect(origin == CGPoint(x: 2200, y: 16))
    }

    @Test func dockedBarWiderThanTheScreenStaysOnItsLeftEdge() {
        let visible = CGRect(x: 0, y: 0, width: 300, height: 500)
        #expect(DockPlacement.bottomCenter(size: CGSize(width: 400, height: 52), in: visible, margin: 16).x == 0)
    }
}
