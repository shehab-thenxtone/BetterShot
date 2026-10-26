import CoreGraphics
import Testing
@testable import BetterShotCore

struct TextHighlightSnapperTests {
    /// A line of words at the given (text, x, width) positions, all `height` tall at vertical position `y`.
    private func makeLine(_ words: [(String, CGFloat, CGFloat)], y: CGFloat, height: CGFloat = 20) -> RecognizedLine {
        let recognized = words.map { RecognizedWord(text: $0.0, rect: CGRect(x: $0.1, y: y, width: $0.2, height: height)) }
        let union = recognized.map(\.rect).reduce(recognized[0].rect) { $0.union($1) }
        return RecognizedLine(text: words.map(\.0).joined(separator: " "), rect: union, words: recognized)
    }

    private var sentence: RecognizedLine {
        makeLine([("Hello", 0, 40), ("big", 50, 30), ("world", 90, 50)], y: 10)
    }

    @Test func snapsToTheWordsUnderTheDragAndMergesThemIntoOneRect() {
        let rects = TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 5, width: 85, height: 30), lines: [sentence], padding: 0)
        #expect(rects == [CGRect(x: 0, y: 10, width: 80, height: 20)]) // "Hello big", not "world"
    }

    @Test func snapsEachLineSeparatelyTopToBottom() {
        let second = makeLine([("Second", 0, 60), ("line", 70, 40)], y: 40)
        let rects = TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 0, width: 200, height: 70), lines: [second, sentence], padding: 0)
        #expect(rects == [CGRect(x: 0, y: 10, width: 140, height: 20), CGRect(x: 0, y: 40, width: 110, height: 20)])
    }

    @Test func aDragThatMissesAllTextSnapsToNothing() {
        #expect(TextHighlightSnapper.snap(selection: CGRect(x: 300, y: 300, width: 10, height: 10), lines: [sentence]).isEmpty)
    }

    @Test func aWordNeedsHalfItsWidthCoveredToBeIncluded() {
        // "Hello" spans 0...40.
        #expect(TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 10, width: 15, height: 20), lines: [sentence], padding: 0).isEmpty)
        #expect(TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 10, width: 25, height: 20), lines: [sentence], padding: 0)
            == [CGRect(x: 0, y: 10, width: 40, height: 20)])
    }

    @Test func aLineNeedsMostOfItsHeightTouchedToBeIncluded() {
        // The line spans y 10...30; this drag only grazes its bottom 2 points.
        #expect(TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 28, width: 200, height: 20), lines: [sentence], padding: 0).isEmpty)
    }

    @Test func paddingGrowsEachSnappedRect() {
        let rects = TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 10, width: 45, height: 20), lines: [sentence], padding: 2)
        #expect(rects == [CGRect(x: -2, y: 8, width: 44, height: 24)])
    }

    @Test func linesWithoutWordRectsFallBackToTheWholeLine() {
        let wholeLine = RecognizedLine(text: "no word boxes", rect: CGRect(x: 0, y: 10, width: 100, height: 20), words: [])
        let rects = TextHighlightSnapper.snap(selection: CGRect(x: 0, y: 10, width: 60, height: 20), lines: [wholeLine], padding: 0)
        #expect(rects == [CGRect(x: 0, y: 10, width: 100, height: 20)])
    }
}
