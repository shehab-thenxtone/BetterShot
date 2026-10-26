import AppKit
import BetterShotCore
import OSLog

/// "Capture Text (OCR)": recognizes the text in a captured area on-device and copies it to the clipboard
/// instead of the image (requirements §3.1 item 8).
@MainActor
final class TextCaptureFlow {
    private let ocr: any OCRProvider
    private let toast: ToastController
    private let logger = Logger(subsystem: "com.bettershot.app", category: "ocr")

    init(ocr: any OCRProvider, toast: ToastController) {
        self.ocr = ocr
        self.toast = toast
    }

    func run(on image: CGImage) async {
        // The very first recognition on a Mac can take ~20 s while Vision prepares its model; say so right away.
        toast.show("Reading text…", symbol: "text.viewfinder", duration: 60)
        do {
            let lines = try await ocr.recognize(in: image, languages: [.english])
            let text = TextAssembler.plainText(from: lines)
            guard !text.isEmpty else {
                toast.show("No text found", symbol: "text.magnifyingglass")
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            toast.show("Copied \(text.count) characters", symbol: "doc.on.clipboard")
        } catch {
            logger.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            toast.show("Couldn't read text", symbol: "exclamationmark.triangle")
        }
    }
}
