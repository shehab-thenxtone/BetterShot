import Testing
@testable import BetterShotCore

struct GIFExportSettingsTests {
    @Test func defaultsMatchSpec() {
        let settings = GIFExportSettings()
        #expect(settings.framesPerSecond == 15)
        #expect(settings.colorDepth == .medium)
        #expect(settings.colorDepth.colorCount == 128)
        #expect(settings.isDitheringEnabled)
        #expect(settings.scale == .full)
    }

    @Test func framesPerSecondIsClampedToThirty() {
        #expect(GIFExportSettings(framesPerSecond: 60).framesPerSecond == 30)
        #expect(GIFExportSettings(framesPerSecond: 0).framesPerSecond == 1)
    }

    @Test func autoModeReusesSourceFrameRateCappedAtThirty() {
        #expect(GIFExportSettings.auto(sourceFramesPerSecond: 60).framesPerSecond == 30)
        #expect(GIFExportSettings.auto(sourceFramesPerSecond: 24).framesPerSecond == 24)
    }

    @Test func autoModeKeepsMediumDitheredFullScale() {
        let settings = GIFExportSettings.auto(sourceFramesPerSecond: 30)
        #expect(settings.colorDepth == .medium)
        #expect(settings.isDitheringEnabled)
        #expect(settings.scale == .full)
    }

    @Test func estimatedSizeGrowsWithFrameRateColorsAndScale() {
        let base = GIFExportSettings(framesPerSecond: 15, colorDepth: .medium, scale: .full)
        let size = { (s: GIFExportSettings) in s.estimatedByteCount(width: 1280, height: 720, duration: 10) }

        #expect(size(GIFExportSettings(framesPerSecond: 30, colorDepth: .medium, scale: .full)) > size(base))
        #expect(size(GIFExportSettings(framesPerSecond: 15, colorDepth: .high, scale: .full)) > size(base))
        #expect(size(GIFExportSettings(framesPerSecond: 15, colorDepth: .medium, scale: .half)) < size(base))
    }

    @Test func estimatedSizeIsZeroForEmptyRecording() {
        #expect(GIFExportSettings().estimatedByteCount(width: 1280, height: 720, duration: 0) == 0)
    }

    @Test func formatsEstimateForDisplay() {
        #expect(GIFExportSettings.formatted(byteCount: 4_400_000) == "~4.2 MB")
        #expect(GIFExportSettings.formatted(byteCount: 512_000) == "~500 KB")
    }
}
