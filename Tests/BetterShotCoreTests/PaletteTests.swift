import Testing
@testable import BetterShotCore

struct PaletteTests {
    private let red = RGB(r: 255, g: 0, b: 0)
    private let green = RGB(r: 0, g: 255, b: 0)
    private let blue = RGB(r: 0, g: 0, b: 255)
    private let black = RGB(r: 0, g: 0, b: 0)
    private let white = RGB(r: 255, g: 255, b: 255)

    /// `count` opaque RGBA pixels of one colour.
    private func solid(_ count: Int, _ color: RGB) -> [UInt8] {
        (0..<count).flatMap { _ in [color.r, color.g, color.b, 255] }
    }

    private func colors(in pixels: [UInt8]) -> Set<RGB> {
        Set(stride(from: 0, to: pixels.count, by: 4).map { RGB(r: pixels[$0], g: pixels[$0 + 1], b: pixels[$0 + 2]) })
    }

    // MARK: Quantizer

    @Test func twoDistinctColorsGiveExactlyThosePaletteColors() {
        let palette = PaletteQuantizer.palette(from: solid(100, red) + solid(100, blue), maxColors: 8)
        #expect(Set(palette) == [red, blue])
    }

    @Test func paletteNeverExceedsTheRequestedSizeButUsesItWhenThereAreEnoughColors() {
        let grays = (0..<256).flatMap { level -> [UInt8] in [UInt8(level), UInt8(level), UInt8(level), 255] }
        #expect(PaletteQuantizer.palette(from: grays, maxColors: 16).count == 16)
        #expect(PaletteQuantizer.palette(from: grays, maxColors: 64).count == 64)
    }

    @Test func aSingleColorYieldsASingleEntry() {
        #expect(PaletteQuantizer.palette(from: solid(50, green), maxColors: 128) == [green])
    }

    @Test func noPixelsYieldNoPalette() {
        #expect(PaletteQuantizer.palette(from: [], maxColors: 64).isEmpty)
        #expect(PaletteQuantizer.palette(from: solid(4, red), maxColors: 0).isEmpty)
    }

    @Test func aOneColorPaletteIsTheAverage() throws {
        let palette = PaletteQuantizer.palette(from: solid(100, red) + solid(100, blue), maxColors: 1)
        let only = try #require(palette.first)
        #expect(palette.count == 1)
        #expect(abs(Int(only.r) - 128) <= 1 && abs(Int(only.b) - 128) <= 1 && only.g == 0)
    }

    // MARK: Mapper

    @Test func eachPixelMapsToTheNearestPaletteColourAndKeepsItsAlpha() {
        let mapper = PaletteMapper(palette: [black, white])
        let input: [UInt8] = [30, 30, 30, 255, 220, 220, 220, 200]
        #expect(mapper.map(rgba: input, width: 2, dithering: false) == [0, 0, 0, 255, 255, 255, 255, 200])
    }

    @Test func exactPaletteColoursMapToThemselves() {
        let mapper = PaletteMapper(palette: [red, green, blue])
        let input = solid(1, red) + solid(1, green) + solid(1, blue)
        #expect(mapper.map(rgba: input, width: 3, dithering: false) == input)
    }

    @Test func ditheredOutputOnlyContainsPaletteColours() {
        let mapper = PaletteMapper(palette: [black, white])
        let gradient = (0..<(32 * 4)).flatMap { index -> [UInt8] in
            let level = UInt8((index % 32) * 8)
            return [level, level, level, 255]
        }
        let output = mapper.map(rgba: gradient, width: 32, dithering: true)
        #expect(output.count == gradient.count)
        #expect(colors(in: output).isSubset(of: [black, white]))
    }

    @Test func ditheringApproximatesAFlatMidGrayWithAMixOfBlackAndWhite() {
        let mapper = PaletteMapper(palette: [black, white])
        let gray = solid(16 * 16, RGB(r: 128, g: 128, b: 128))

        let dithered = mapper.map(rgba: gray, width: 16, dithering: true)
        let whiteCount = stride(from: 0, to: dithered.count, by: 4).filter { dithered[$0] == 255 }.count
        let share = Double(whiteCount) / 256
        #expect(share > 0.4 && share < 0.6)

        let flat = mapper.map(rgba: gray, width: 16, dithering: false)
        #expect(colors(in: flat).count == 1) // without dithering the whole area collapses to one colour
    }

    @Test func anEmptyPaletteFallsBackToBlackInsteadOfCrashing() {
        let mapper = PaletteMapper(palette: [])
        #expect(mapper.map(rgba: solid(1, RGB(r: 200, g: 0, b: 0)), width: 1, dithering: false) == [0, 0, 0, 255])
    }
}
