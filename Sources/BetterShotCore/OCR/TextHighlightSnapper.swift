import CoreGraphics

/// Makes the text highlighter behave like highlighting in a PDF: instead of a freehand rectangle over arbitrary
/// pixels, the highlight snaps to the words the drag actually covers, one even band per line.
public enum TextHighlightSnapper {
    /// A word counts as covered when at least this share of its width lies inside the drag.
    private static let minimumWordCoverage: CGFloat = 0.5
    /// A line is considered at all when the drag touches at least this share of its height.
    private static let minimumLineCoverage: CGFloat = 0.4

    /// One rect per covered line, top to bottom, in the same coordinate space as `selection` and `lines`.
    /// Empty when the drag doesn't cover any text, so callers can fall back to the plain rectangle.
    public static func snap(selection: CGRect, lines: [RecognizedLine], padding: CGFloat = 1) -> [CGRect] {
        lines
            .sorted { ($0.rect.minY, $0.rect.minX) < ($1.rect.minY, $1.rect.minX) }
            .compactMap { line in
                guard verticalCoverage(of: line.rect, by: selection) >= minimumLineCoverage else { return nil }

                let words = line.words.isEmpty ? [RecognizedWord(text: line.text, rect: line.rect)] : line.words
                let covered = words.filter { horizontalCoverage(of: $0.rect, by: selection) >= minimumWordCoverage }
                guard let first = covered.first else { return nil }

                let span = covered.dropFirst().reduce(first.rect) { $0.union($1.rect) }
                // Use the whole line's height so highlights on one line are level regardless of descenders.
                return CGRect(x: span.minX, y: line.rect.minY, width: span.width, height: line.rect.height)
                    .insetBy(dx: -padding, dy: -padding)
            }
    }

    private static func horizontalCoverage(of rect: CGRect, by selection: CGRect) -> CGFloat {
        guard rect.width > 0 else { return 0 }
        let overlap = min(rect.maxX, selection.maxX) - max(rect.minX, selection.minX)
        return max(0, overlap) / rect.width
    }

    private static func verticalCoverage(of rect: CGRect, by selection: CGRect) -> CGFloat {
        guard rect.height > 0 else { return 0 }
        let overlap = min(rect.maxY, selection.maxY) - max(rect.minY, selection.minY)
        return max(0, overlap) / rect.height
    }
}
