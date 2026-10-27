/// What the engine needs from the screen: a way to scroll the area and a way to see it. Implemented against the
/// real screen in the app and against a fake page in tests.
public protocol ScrollingSurface: Sendable {
    /// Scrolls so later content comes into view; a negative value scrolls back. Units are scroll-wheel units.
    func scroll(by pixels: Int) async
    /// A picture of the area once any scrolling animation has finished.
    func settledFrame() async throws -> PixelFrame
}

/// The decision loop of Scrolling Capture (requirements §3.1 item 6): scroll, look, measure how far the content
/// really moved, keep only what's new, repeat until the content ends.
///
/// Apps scroll by different amounts for the same input, so the step is a guess that the measurement corrects.
/// If a step overshoots and the frames no longer overlap, the engine scrolls back, halves the step and carries on.
public enum ScrollCaptureEngine {
    public struct Limits: Sendable {
        public var maximumFrames: Int
        public var maximumLength: Int

        /// `maximumLength` is in pixels of the stitched image: a runaway infinite-scroll page can't fill memory.
        public init(maximumFrames: Int = 80, maximumLength: Int = 30_000) {
            self.maximumFrames = maximumFrames
            self.maximumLength = maximumLength
        }
    }

    /// The first step covers this share of the area, which leaves most of each frame shared with the next.
    private static let firstStepShare = 0.6
    private static let largestMinimumStep = 40
    private static let smallestStep = 20
    private static let maximumRecoveries = 3

    /// Captures the area and everything scrolled into view along `axis`, stopping at the end of the content, at a
    /// limit, when `shouldStop` returns true, or when it can't keep track of the content. `extent` is the area's
    /// size along the axis (it sets the first step). `onProgress` receives the number of frames captured so far.
    public static func capture(
        from surface: some ScrollingSurface,
        axis: ScrollAxis,
        extent: Int,
        limits: Limits = Limits(),
        shouldStop: @Sendable () -> Bool = { false },
        onProgress: @Sendable (Int) -> Void = { _ in }
    ) async throws -> ScrollStitchBuilder {
        var current = try await surface.settledFrame()
        var builder = ScrollStitchBuilder(first: current, axis: axis)
        var step = max(largestMinimumStep, Int(Double(extent) * firstStepShare))
        var recoveries = 0
        var direction = 1 // becomes -1 if this surface turns out to scroll the other way
        var hasProbed = false
        onProgress(1)

        while !shouldStop(), builder.frameCount < limits.maximumFrames, builder.length < limits.maximumLength {
            await surface.scroll(by: step * direction)
            var next = try await surface.settledFrame()
            var measured = ScrollStitcher.shift(from: current, to: next, axis: axis)

            if measured == 0, builder.frameCount == 1, !hasProbed {
                // The very first step moved nothing: either there is nothing to scroll, or this surface's wheel
                // convention is the opposite of ours (we start at the top, so scrolling backwards goes nowhere).
                // Try the opposite direction once.
                hasProbed = true
                await surface.scroll(by: -step * direction)
                let probe = try await surface.settledFrame()
                guard let shift = ScrollStitcher.shift(from: current, to: probe, axis: axis), shift > 0 else {
                    await surface.scroll(by: step * direction) // genuinely nothing to scroll: put it back
                    return builder
                }
                direction = -direction
                next = probe
                measured = shift
            }

            switch measured {
            case 0?:
                return builder // nothing moved: the end of the content
            case let shift?:
                builder.append(next, shift: shift)
                current = next
                recoveries = 0
                onProgress(builder.frameCount)
            case nil:
                // Scrolled further than the overlap allows, or the content changed. Go back and take smaller steps.
                recoveries += 1
                guard recoveries <= maximumRecoveries else { return builder }
                await surface.scroll(by: -step * direction)
                let restored = try await surface.settledFrame()
                guard ScrollStitcher.shift(from: current, to: restored, axis: axis) == 0 else { return builder }
                step = max(smallestStep, step / 2)
            }
        }
        return builder
    }
}
