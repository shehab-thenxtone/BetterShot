import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import BetterShotServices

struct ImageExporterTests {
    private func makeImage(width: Int = 40, height: Int = 20, alpha: CGFloat = 1) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        if alpha > 0 {
            context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: alpha))
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        }
        return context.makeImage()!
    }

    @Test func formatsExposeExtensionsAndNames() {
        #expect(ExportFormat.allCases == [.png, .jpeg, .pdf])
        #expect(ExportFormat.png.fileExtension == "png")
        #expect(ExportFormat.jpeg.fileExtension == "jpg")
        #expect(ExportFormat.pdf.fileExtension == "pdf")
        #expect(ExportFormat.jpeg.displayName == "JPEG")
    }

    @Test func pngHasThePNGSignature() throws {
        let data = try ImageExporter.data(for: makeImage(), format: .png)
        #expect(Array(data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])
    }

    @Test func jpegHasTheJPEGSignature() throws {
        let data = try ImageExporter.data(for: makeImage(), format: .jpeg)
        #expect(Array(data.prefix(3)) == [0xFF, 0xD8, 0xFF])
    }

    @Test func jpegFlattensTransparencyOntoWhiteInsteadOfBlack() throws {
        // Right half of the image is fully transparent.
        let data = try ImageExporter.data(for: makeImage(width: 40, height: 20), format: .jpeg)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

        var buffer = [UInt8](repeating: 0, count: decoded.width * decoded.height * 4)
        buffer.withUnsafeMutableBytes { pointer in
            CGContext(
                data: pointer.baseAddress, width: decoded.width, height: decoded.height, bitsPerComponent: 8,
                bytesPerRow: decoded.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!.draw(decoded, in: CGRect(x: 0, y: 0, width: decoded.width, height: decoded.height))
        }
        let index = (5 * decoded.width + 35) * 4 // a pixel in the transparent half
        #expect(buffer[index] > 240 && buffer[index + 1] > 240 && buffer[index + 2] > 240)
    }

    @Test func pdfIsAPageSizedInPointsFromThePointScale() throws {
        let data = try ImageExporter.data(for: makeImage(width: 400, height: 200), format: .pdf, pointScale: 2)
        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")

        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))
        let page = try #require(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(box.width == 200 && box.height == 100)
    }
}
