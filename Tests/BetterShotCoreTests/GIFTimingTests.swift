import Testing
@testable import BetterShotCore

struct GIFTimingTests {
    @Test func frameTimesAreEvenlySpacedFromZero() {
        let times = GIFTiming.frameTimes(duration: 1, framesPerSecond: 15)
        #expect(times.count == 15)
        #expect(times.first == 0)
        #expect(abs(times[14] - 14.0 / 15) < 1e-9)
    }

    @Test func partialSecondsRoundDownToWholeFrames() {
        #expect(GIFTiming.frameTimes(duration: 0.5, framesPerSecond: 10).count == 5)
        #expect(GIFTiming.frameTimes(duration: 2.49, framesPerSecond: 10).count == 24)
    }

    @Test func aVeryShortRecordingStillYieldsOneFrame() {
        #expect(GIFTiming.frameTimes(duration: 0.01, framesPerSecond: 15) == [0])
        #expect(GIFTiming.frameTimes(duration: 0, framesPerSecond: 15) == [0])
    }

    @Test func nonPositiveFrameRatesAreTreatedAsOne() {
        #expect(GIFTiming.frameTimes(duration: 3, framesPerSecond: 0).count == 3)
    }

    @Test func frameDelaysRoundToWholeCentisecondsBecauseThatIsGIFsResolution() {
        #expect(GIFTiming.frameDelay(framesPerSecond: 10) == 0.10)
        #expect(GIFTiming.frameDelay(framesPerSecond: 15) == 0.07) // 6.67 cs → 7
        #expect(GIFTiming.frameDelay(framesPerSecond: 30) == 0.03) // 3.33 cs → 3
    }

    @Test func frameDelayNeverDropsBelowOneCentisecond() {
        #expect(GIFTiming.frameDelay(framesPerSecond: 1000) == 0.01)
    }
}
