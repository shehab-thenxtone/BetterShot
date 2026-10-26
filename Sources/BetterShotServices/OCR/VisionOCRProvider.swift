import BetterShotCore
import CoreGraphics
import Foundation
import Vision

/// On-device text recognition with Vision (`VNRecognizeTextRequest`, accurate mode). Nothing leaves the Mac.
public struct VisionOCRProvider: OCRProvider {
    public init() {}

    public func recognize(in image: CGImage, languages: [OCRLanguage]) async throws(OCRError) -> [RecognizedLine] {
        let identifiers = languages.map(\.identifier)
        do {
            // Vision's perform() is synchronous and can take a while on a large capture; keep it off the main actor.
            return try await Task.detached(priority: .userInitiated) {
                try Self.perform(on: image, languages: identifiers)
            }.value
        } catch {
            throw .failed(error.localizedDescription)
        }
    }

    // MARK: Private

    private static func perform(on image: CGImage, languages: [String]) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        let size = CGSize(width: image.width, height: image.height)
        return (request.results ?? []).compactMap { line(from: $0, imageSize: size) }
    }

    private static func line(from observation: VNRecognizedTextObservation, imageSize: CGSize) -> RecognizedLine? {
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = candidate.string

        var words: [RecognizedWord] = []
        for range in text.ranges(of: /\S+/) {
            guard let box = try? candidate.boundingBox(for: range) else { continue }
            words.append(RecognizedWord(text: String(text[range]), rect: pixelRect(box.boundingBox, in: imageSize)))
        }
        return RecognizedLine(text: text, rect: pixelRect(observation.boundingBox, in: imageSize), words: words)
    }

    /// Vision reports 0...1 rects with a bottom-left origin; the rest of the app uses image pixels, top-left.
    private static func pixelRect(_ normalized: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalized.minX * size.width,
            y: (1 - normalized.maxY) * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        )
    }
}
