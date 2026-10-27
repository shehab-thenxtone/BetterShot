import Foundation
import Testing
@testable import BetterShotCore

struct ScrollCaptureEngineTests {
    // MARK: A fake page behind a scrolling viewport

    private static func makePage(width: Int, height: Int, seed: UInt64 = 1) -> PixelFrame {
        var state = seed
        var bytes: [UInt8] = []
        bytes.reserveCapacity(width * height * 4)
        for _ in 0..<(width * height) {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let value = state >> 33
            bytes += [UInt8(value & 255), UInt8((value >> 8) & 255), UInt8((value >> 16) & 255), 255]
        }
        return PixelFrame(width: width, height: height, rgba: bytes)!
    }

    /// A page seen through a viewport. `multiplier` is how far content really moves per requested scroll unit
    /// (apps differ); the offset is clamped at both ends like a real scroll view.
    private final class FakeSurface: ScrollingSurface, @unchecked Sendable {
        let page: PixelFrame
        let viewport: Int
        let axis: ScrollAxis
        let multiplier: Double
        let changesEveryFrame: Bool
        /// A surface whose wheel convention is the opposite of what the engine assumes.
        let isInverted: Bool
        private(set) var offset = 0
        private(set) var scrollCalls = 0
        private var captures = 0

        init(
            page: PixelFrame, viewport: Int, axis: ScrollAxis = .vertical, multiplier: Double = 1,
            changesEveryFrame: Bool = false, isInverted: Bool = false
        ) {
            self.page = page
            self.viewport = viewport
            self.axis = axis
            self.multiplier = multiplier
            self.changesEveryFrame = changesEveryFrame
            self.isInverted = isInverted
        }

        private var maximumOffset: Int { (axis == .vertical ? page.height : page.width) - viewport }

        func scroll(by pixels: Int) async {
            scrollCalls += 1
            let requested = isInverted ? -pixels : pixels
            offset = min(max(offset + Int((Double(requested) * multiplier).rounded()), 0), maximumOffset)
        }

        func settledFrame() async throws -> PixelFrame {
            captures += 1
            if changesEveryFrame { return ScrollCaptureEngineTests.makePage(width: page.width, height: viewport, seed: UInt64(captures) + 1000) }
            switch axis {
            case .vertical:
                let stride = page.width * 4
                return PixelFrame(width: page.width, height: viewport, rgba: Array(page.rgba[(offset * stride)..<((offset + viewport) * stride)]))!
            case .horizontal:
                var bytes: [UInt8] = []
                for row in 0..<page.height {
                    let start = (row * page.width + offset) * 4
                    bytes += page.rgba[start..<(start + viewport * 4)]
                }
                return PixelFrame(width: viewport, height: page.height, rgba: bytes)!
            }
        }
    }

    private final class StopSwitch: @unchecked Sendable {
        private let lock = NSLock()
        private var stopped = false
        var isStopped: Bool { lock.withLock { stopped } }
        func stop() { lock.withLock { stopped = true } }
    }

    // MARK: Tests

    @Test func capturesATallPageExactly() async throws {
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(builder.result == page) // including the final, partial step at the end
        #expect(builder.frameCount > 2)
    }

    @Test func capturesAWidePageExactly() async throws {
        let page = Self.makePage(width: 450, height: 40)
        let surface = FakeSurface(page: page, viewport: 100, axis: .horizontal)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .horizontal, extent: 100)

        #expect(builder.result == page)
    }

    @Test func copesWithAppsThatScrollMoreThanAskedFor() async throws {
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100, multiplier: 1.3)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(builder.result == page)
    }

    @Test func backsUpAndTakesSmallerStepsWhenAScrollOvershootsTheOverlap() async throws {
        // Each requested unit moves 2.5×, so the first step (60) jumps 150 rows: no overlap with a 100-row viewport.
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100, multiplier: 2.5)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(builder.result == page)
    }

    @Test func correctsItselfWhenTheSurfaceScrollsTheOtherWay() async throws {
        // If the wheel sign convention is reversed, the first step goes nowhere (we start at the top). The engine
        // probes the opposite direction once and carries on that way.
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100, isInverted: true)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(builder.result == page)
    }

    @Test func correctsItselfOnAnInvertedHorizontalSurfaceToo() async throws {
        let page = Self.makePage(width: 450, height: 40)
        let surface = FakeSurface(page: page, viewport: 100, axis: .horizontal, isInverted: true)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .horizontal, extent: 100)

        #expect(builder.result == page)
    }

    @Test func anUnscrollableSurfaceIsLeftWhereItWasAfterTheProbe() async throws {
        let surface = FakeSurface(page: Self.makePage(width: 40, height: 450), viewport: 100, multiplier: 0)

        _ = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(surface.offset == 0)
    }

    @Test func aSurfaceThatDoesNotScrollYieldsASingleFrame() async throws {
        let surface = FakeSurface(page: Self.makePage(width: 40, height: 450), viewport: 100, multiplier: 0)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(builder.frameCount == 1)
        #expect(builder.length == 100)
    }

    @Test func stopsWhenAskedAndKeepsWhatItHas() async throws {
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100)
        let stop = StopSwitch()

        let builder = try await ScrollCaptureEngine.capture(
            from: surface, axis: .vertical, extent: 100,
            shouldStop: { stop.isStopped },
            onProgress: { if $0 >= 3 { stop.stop() } }
        )

        #expect(builder.frameCount == 3)
        // What was captured is the top of the page, correctly stitched.
        let kept = builder.result
        #expect(kept.rgba == Array(page.rgba[0..<(kept.height * 40 * 4)]))
    }

    @Test func respectsTheFrameLimit() async throws {
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100)

        let builder = try await ScrollCaptureEngine.capture(
            from: surface, axis: .vertical, extent: 100, limits: .init(maximumFrames: 4)
        )

        #expect(builder.frameCount == 4)
    }

    @Test func respectsTheLengthLimit() async throws {
        let page = Self.makePage(width: 40, height: 450)
        let surface = FakeSurface(page: page, viewport: 100)

        let builder = try await ScrollCaptureEngine.capture(
            from: surface, axis: .vertical, extent: 100, limits: .init(maximumLength: 200)
        )

        #expect(builder.length >= 200)
        #expect(builder.length < 300) // stopped at the first frame that reached the limit
    }

    @Test func contentThatKeepsChangingEndsQuicklyInsteadOfLoopingForever() async throws {
        let surface = FakeSurface(page: Self.makePage(width: 40, height: 450), viewport: 100, changesEveryFrame: true)

        let builder = try await ScrollCaptureEngine.capture(from: surface, axis: .vertical, extent: 100)

        #expect(builder.frameCount == 1)
        #expect(surface.scrollCalls < 20)
    }
}
