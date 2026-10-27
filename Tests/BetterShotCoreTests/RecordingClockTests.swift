import Testing
@testable import BetterShotCore

struct RecordingClockTests {
    private func isClose(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }

    @Test func firstFrameIsTimeZeroAndLaterFramesAreRelativeToIt() {
        var clock = RecordingClock()
        #expect(isClose(clock.retime(100), 0))
        #expect(isClose(clock.retime(100.5), 0.5))
        #expect(isClose(clock.retime(102), 2))
    }

    @Test func framesInsideAPausedIntervalAreDroppedAndTimeContinuesSeamlessly() {
        var clock = RecordingClock()
        #expect(isClose(clock.retime(100), 0))
        #expect(isClose(clock.retime(101), 1))
        #expect(isClose(clock.retime(102), 2))

        clock.pause(at: 102.5)
        #expect(clock.retime(103) == nil)
        #expect(clock.retime(104) == nil)

        clock.resume(at: 105)
        // 2.5 s were paused, so a frame 3.5 s after the last one lands just 1 s after it in the file.
        #expect(isClose(clock.retime(105.5), 3))
    }

    @Test func aPauseWithNoFramesDuringItStillRemovesTheGap() {
        // A static screen delivers no frames, so the pause can't be discovered from frame timestamps.
        var clock = RecordingClock()
        _ = clock.retime(100)
        clock.pause(at: 101)
        clock.resume(at: 104)
        #expect(isClose(clock.retime(104.2), 1.2))
    }

    @Test func severalPausesAccumulate() {
        var clock = RecordingClock()
        _ = clock.retime(0)
        clock.pause(at: 1)
        clock.resume(at: 2)
        #expect(isClose(clock.retime(2.5), 1.5)) // 1 s paused
        clock.pause(at: 3)
        clock.resume(at: 5)
        #expect(isClose(clock.retime(5.5), 2.5)) // 3 s paused in total
    }

    @Test func aLateFrameStampedBeforeThePauseStartedIsStillKept() {
        var clock = RecordingClock()
        _ = clock.retime(100)
        clock.pause(at: 102.5)
        #expect(isClose(clock.retime(102.4), 2.4))
    }

    @Test func pausingTwiceKeepsTheFirstPauseAndResumingWithoutAPauseDoesNothing() {
        var clock = RecordingClock()
        _ = clock.retime(100)
        clock.resume(at: 100.5) // nothing to resume

        clock.pause(at: 101)
        clock.pause(at: 102) // ignored
        clock.resume(at: 103)
        #expect(isClose(clock.retime(104), 2)) // paused 101…103 = 2 s
    }

    @Test func aPauseBeforeTheFirstFrameDoesNotShiftTheTimeline() {
        var clock = RecordingClock()
        clock.pause(at: 99)
        #expect(clock.retime(99.5) == nil)
        clock.resume(at: 100)
        #expect(isClose(clock.retime(100.1), 0))
    }

    @Test func clockStringsShowMinutesAndSecondsAndHoursWhenNeeded() {
        #expect(RecordingTime.clockString(0) == "0:00")
        #expect(RecordingTime.clockString(7.9) == "0:07") // whole seconds, rounded down
        #expect(RecordingTime.clockString(723) == "12:03")
        #expect(RecordingTime.clockString(3723) == "1:02:03")
        #expect(RecordingTime.clockString(-5) == "0:00")
    }

    @Test func isPausedReflectsTheCurrentState() {
        var clock = RecordingClock()
        #expect(!clock.isPaused)
        clock.pause(at: 1)
        #expect(clock.isPaused)
        clock.resume(at: 2)
        #expect(!clock.isPaused)
    }
}
