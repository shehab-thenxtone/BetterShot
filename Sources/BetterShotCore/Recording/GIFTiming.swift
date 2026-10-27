/// Frame timing for GIF export. GIF stores each frame's delay in whole hundredths of a second.
public enum GIFTiming {
    /// Timestamps (seconds) to sample from a video of `duration` at `framesPerSecond`; always at least one.
    public static func frameTimes(duration: Double, framesPerSecond: Int) -> [Double] {
        let fps = max(framesPerSecond, 1)
        let count = max(1, Int((max(duration, 0) * Double(fps)).rounded(.down)))
        return (0..<count).map { Double($0) / Double(fps) }
    }

    /// Per-frame delay in seconds, rounded to GIF's 1/100 s resolution (so 15 fps plays as 14.3 fps) and never below 1/100 s.
    public static func frameDelay(framesPerSecond: Int) -> Double {
        let fps = max(framesPerSecond, 1)
        let centiseconds = max(1, (100.0 / Double(fps)).rounded())
        return centiseconds / 100
    }
}
