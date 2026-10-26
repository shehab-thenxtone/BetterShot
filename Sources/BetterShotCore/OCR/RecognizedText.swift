import CoreGraphics
import Foundation

/// A recognition language. Launch scope is English only (requirements §3.1 item 8); the type exists so further
/// language packs are just more values passed to the provider, not a pipeline change.
public struct OCRLanguage: Equatable, Hashable, Sendable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }

    public static let english = OCRLanguage(identifier: "en-US")
}

/// One recognized word. `rect` is in image pixels with a top-left origin.
public struct RecognizedWord: Equatable, Sendable {
    public let text: String
    public let rect: CGRect

    public init(text: String, rect: CGRect) {
        self.text = text
        self.rect = rect
    }
}

/// One recognized line of text with its words. `rect` is in image pixels with a top-left origin.
public struct RecognizedLine: Equatable, Sendable {
    public let text: String
    public let rect: CGRect
    public let words: [RecognizedWord]

    public init(text: String, rect: CGRect, words: [RecognizedWord]) {
        self.text = text
        self.rect = rect
        self.words = words
    }

    /// Multiplies every coordinate by `factor` (e.g. 1 / pointScale to turn pixels into document points).
    public func scaled(by factor: CGFloat) -> RecognizedLine {
        RecognizedLine(
            text: text,
            rect: Self.scale(rect, by: factor),
            words: words.map { RecognizedWord(text: $0.text, rect: Self.scale($0.rect, by: factor)) }
        )
    }

    private static func scale(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        CGRect(x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor, height: rect.height * factor)
    }
}

public enum OCRError: Error, Equatable, LocalizedError, Sendable {
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .failed(let reason): "Text recognition failed: \(reason)"
        }
    }
}

/// On-device text recognition. Implemented with Vision; faked in tests.
public protocol OCRProvider: Sendable {
    func recognize(in image: CGImage, languages: [OCRLanguage]) async throws(OCRError) -> [RecognizedLine]
}

public enum TextAssembler {
    /// Plain text in reading order: rows top to bottom, and lines that share a row left to right.
    /// Blank lines are dropped and each line is trimmed.
    public static func plainText(from lines: [RecognizedLine]) -> String {
        var rows: [[RecognizedLine]] = []
        for line in lines.sorted(by: { $0.rect.midY < $1.rect.midY }) {
            if let anchor = rows.last?.first,
               abs(line.rect.midY - anchor.rect.midY) < min(line.rect.height, anchor.rect.height) / 2 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows
            .flatMap { $0.sorted { $0.rect.minX < $1.rect.minX } }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
