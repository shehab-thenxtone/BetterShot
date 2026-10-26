import Testing
@testable import BetterShotCore

struct ImageScaleTests {
    @Test func unknownOrInvalidDensityHasNoScale() {
        #expect(ImageScale.pointScale(forDPI: nil) == nil)
        #expect(ImageScale.pointScale(forDPI: 0) == nil)
        #expect(ImageScale.pointScale(forDPI: -72) == nil)
    }

    @Test func densityIsRelativeToThe72DPIPointGrid() {
        #expect(ImageScale.pointScale(forDPI: 72) == 1)
        #expect(ImageScale.pointScale(forDPI: 144) == 2) // macOS Retina screenshots
        #expect(ImageScale.pointScale(forDPI: 216) == 3)
    }

    @Test func scaleIsClampedBetweenOneAndFour() {
        #expect(ImageScale.pointScale(forDPI: 36) == 1)
        #expect(ImageScale.pointScale(forDPI: 300) == 4)
        #expect(ImageScale.pointScale(forDPI: 600) == 4)
    }
}
