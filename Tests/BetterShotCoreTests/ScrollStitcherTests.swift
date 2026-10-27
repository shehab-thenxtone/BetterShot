import Testing
@testable import BetterShotCore

struct ScrollStitcherTests {
    // MARK: Helpers

    /// A reproducible "page" whose every row and column is distinct, so a correct alignment is unambiguous.
    private func makeDocument(width: Int, height: Int, seed: UInt64 = 1) -> PixelFrame {
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

    /// What a scrolled viewport shows: `height` rows starting at row `y`.
    private func rows(of document: PixelFrame, from y: Int, count height: Int) -> PixelFrame {
        let stride = document.width * 4
        return PixelFrame(width: document.width, height: height, rgba: Array(document.rgba[(y * stride)..<((y + height) * stride)]))!
    }

    /// A horizontally scrolled viewport: `width` columns starting at column `x`.
    private func columns(of document: PixelFrame, from x: Int, count width: Int) -> PixelFrame {
        var bytes: [UInt8] = []
        for row in 0..<document.height {
            let start = (row * document.width + x) * 4
            bytes += document.rgba[start..<(start + width * 4)]
        }
        return PixelFrame(width: width, height: document.height, rgba: bytes)!
    }

    private func solid(width: Int, height: Int, value: UInt8) -> PixelFrame {
        PixelFrame(width: width, height: height, rgba: [UInt8](repeating: value, count: width * height * 4))!
    }

    // MARK: Finding the shift

    @Test func findsHowFarContentScrolledVertically() {
        let page = makeDocument(width: 40, height: 300)
        let shift = ScrollStitcher.shift(from: rows(of: page, from: 0, count: 100), to: rows(of: page, from: 70, count: 100), axis: .vertical)
        #expect(shift == 70)
    }

    @Test func findsHowFarContentScrolledHorizontally() {
        let page = makeDocument(width: 300, height: 40)
        let shift = ScrollStitcher.shift(from: columns(of: page, from: 0, count: 100), to: columns(of: page, from: 70, count: 100), axis: .horizontal)
        #expect(shift == 70)
    }

    @Test func identicalFramesMeanTheEndOfTheContent() {
        let frame = rows(of: makeDocument(width: 40, height: 300), from: 20, count: 100)
        #expect(ScrollStitcher.shift(from: frame, to: frame, axis: .vertical) == 0)
        #expect(ScrollStitcher.shift(from: solid(width: 8, height: 50, value: 255), to: solid(width: 8, height: 50, value: 255), axis: .vertical) == 0)
    }

    @Test func unrelatedFramesHaveNoShift() {
        let first = rows(of: makeDocument(width: 40, height: 300, seed: 1), from: 0, count: 100)
        let second = rows(of: makeDocument(width: 40, height: 300, seed: 2), from: 0, count: 100)
        #expect(ScrollStitcher.shift(from: first, to: second, axis: .vertical) == nil)
    }

    @Test func aSmallOverlapIsStillEnoughButTwoRowsIsNot() {
        let page = makeDocument(width: 40, height: 300)
        let top = rows(of: page, from: 0, count: 100)
        #expect(ScrollStitcher.shift(from: top, to: rows(of: page, from: 90, count: 100), axis: .vertical) == 90) // 10 shared rows
        #expect(ScrollStitcher.shift(from: top, to: rows(of: page, from: 98, count: 100), axis: .vertical) == nil) // 2 shared rows: no evidence
    }

    @Test func framesOfDifferentSizesCannotBeMatched() {
        let page = makeDocument(width: 40, height: 300)
        #expect(ScrollStitcher.shift(from: rows(of: page, from: 0, count: 100), to: rows(of: page, from: 0, count: 90), axis: .vertical) == nil)
    }

    @Test func aStickyHeaderDoesNotThrowTheAlignmentOff() {
        // The top 10 rows are a fixed header that doesn't scroll; the rest is the page.
        let page = makeDocument(width: 40, height: 300)
        let header = makeDocument(width: 40, height: 10, seed: 99)
        func viewport(at offset: Int) -> PixelFrame {
            PixelFrame(width: 40, height: 100, rgba: header.rgba + rows(of: page, from: offset, count: 90).rgba)!
        }
        #expect(ScrollStitcher.shift(from: viewport(at: 0), to: viewport(at: 60), axis: .vertical) == 60)
    }

    @Test func aFewChangedRowsFromAnimationsOrACursorAreTolerated() {
        let page = makeDocument(width: 40, height: 300)
        let first = rows(of: page, from: 0, count: 100)
        var changed = rows(of: page, from: 70, count: 100)
        var bytes = changed.rgba
        for row in 0..<4 { // 4 of the 30 shared rows differ
            for index in (row * 40 * 4)..<((row + 1) * 40 * 4) { bytes[index] = ~bytes[index] }
        }
        changed = PixelFrame(width: 40, height: 100, rgba: bytes)!
        #expect(ScrollStitcher.shift(from: first, to: changed, axis: .vertical) == 70)
    }

    // MARK: Stitching

    @Test func stitchingOverlappingViewportsRebuildsTheOriginalPageExactly() throws {
        let page = makeDocument(width: 40, height: 400)
        let offsets = [0, 70, 150, 230, 300]
        let viewports = offsets.map { rows(of: page, from: $0, count: 100) }

        var builder = ScrollStitchBuilder(first: viewports[0], axis: .vertical)
        for (previous, next) in zip(viewports, viewports.dropFirst()) {
            let shift = try #require(ScrollStitcher.shift(from: previous, to: next, axis: .vertical))
            builder.append(next, shift: shift)
        }

        #expect(builder.frameCount == 5)
        #expect(builder.length == 400)
        #expect(builder.result == page)
    }

    @Test func stitchingHorizontalViewportsRebuildsTheOriginalPageExactly() throws {
        let page = makeDocument(width: 400, height: 40)
        let offsets = [0, 80, 160, 240, 300] // every step overlaps the previous 100-wide viewport
        let viewports = offsets.map { columns(of: page, from: $0, count: 100) }

        var builder = ScrollStitchBuilder(first: viewports[0], axis: .horizontal)
        for (previous, next) in zip(viewports, viewports.dropFirst()) {
            let shift = try #require(ScrollStitcher.shift(from: previous, to: next, axis: .horizontal))
            builder.append(next, shift: shift)
        }

        #expect(builder.length == 400)
        #expect(builder.result == page)
    }

    @Test func aBuilderWithOnlyTheFirstFrameIsThatFrame() {
        let frame = rows(of: makeDocument(width: 40, height: 300), from: 0, count: 100)
        let builder = ScrollStitchBuilder(first: frame, axis: .vertical)
        #expect(builder.frameCount == 1)
        #expect(builder.length == 100)
        #expect(builder.result == frame)
    }

    @Test func appendingAZeroShiftAddsNothing() {
        let frame = rows(of: makeDocument(width: 40, height: 300), from: 0, count: 100)
        var builder = ScrollStitchBuilder(first: frame, axis: .vertical)
        builder.append(frame, shift: 0)
        #expect(builder.frameCount == 1)
        #expect(builder.result == frame)
    }
}
