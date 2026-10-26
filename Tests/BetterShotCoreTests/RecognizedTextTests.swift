import CoreGraphics
import Testing
@testable import BetterShotCore

struct RecognizedTextTests {
    private func line(_ text: String, x: CGFloat = 0, y: CGFloat, width: CGFloat = 100, height: CGFloat = 20) -> RecognizedLine {
        RecognizedLine(text: text, rect: CGRect(x: x, y: y, width: width, height: height), words: [])
    }

    @Test func englishIsTheLaunchLanguage() {
        #expect(OCRLanguage.english.identifier == "en-US")
    }

    @Test func plainTextReadsTopToBottomRegardlessOfInputOrder() {
        let lines = [line("third", y: 80), line("first", y: 10), line("second", y: 45)]
        #expect(TextAssembler.plainText(from: lines) == "first\nsecond\nthird")
    }

    @Test func plainTextReadsASingleRowLeftToRight() {
        // Two columns on the same visual row, slightly different heights: left column first.
        let lines = [line("right", x: 300, y: 12), line("left", x: 0, y: 10), line("below", x: 0, y: 60)]
        #expect(TextAssembler.plainText(from: lines) == "left\nright\nbelow")
    }

    @Test func plainTextDropsBlankLinesAndTrimsWhitespace() {
        let lines = [line("  hello  ", y: 10), line("   ", y: 40), line("", y: 70), line("world", y: 100)]
        #expect(TextAssembler.plainText(from: lines) == "hello\nworld")
    }

    @Test func plainTextOfNothingIsEmpty() {
        #expect(TextAssembler.plainText(from: []) == "")
    }

    @Test func scalingConvertsPixelsToPointsForLinesAndWords() {
        let word = RecognizedWord(text: "Hi", rect: CGRect(x: 20, y: 40, width: 60, height: 30))
        let pixels = RecognizedLine(text: "Hi", rect: CGRect(x: 20, y: 40, width: 60, height: 30), words: [word])

        let points = pixels.scaled(by: 0.5)

        #expect(points.rect == CGRect(x: 10, y: 20, width: 30, height: 15))
        #expect(points.words == [RecognizedWord(text: "Hi", rect: CGRect(x: 10, y: 20, width: 30, height: 15))])
        #expect(points.text == "Hi")
    }
}
