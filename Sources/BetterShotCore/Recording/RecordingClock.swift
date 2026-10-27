/// Maps frame timestamps from a live capture to times in the output file, skipping paused stretches.
/// Timestamps are seconds in any single timebase (the recorder uses the host clock). Pause and resume are
/// stamped with the same clock, because a static screen delivers no frames during a pause to reveal it.
public struct RecordingClock: Sendable {
    private var firstTimestamp: Double?
    private var pausedAt: Double?
    private var totalPaused: Double = 0

    public init() {}

    public var isPaused: Bool { pausedAt != nil }

    /// Starts a pause. Pausing while already paused keeps the earlier pause time.
    public mutating func pause(at timestamp: Double) {
        if pausedAt == nil { pausedAt = timestamp }
    }

    /// Ends a pause. Resuming when not paused does nothing.
    public mutating func resume(at timestamp: Double) {
        guard let start = pausedAt else { return }
        totalPaused += max(0, timestamp - start)
        pausedAt = nil
    }

    /// The frame's time in the output file, or nil if it falls inside a pause and should be dropped.
    /// The first frame defines time zero; pauses before it don't count.
    public mutating func retime(_ timestamp: Double) -> Double? {
        if let start = pausedAt, timestamp >= start { return nil }
        let first: Double
        if let existing = firstTimestamp {
            first = existing
        } else {
            firstTimestamp = timestamp
            totalPaused = 0
            first = timestamp
        }
        return timestamp - first - totalPaused
    }
}
