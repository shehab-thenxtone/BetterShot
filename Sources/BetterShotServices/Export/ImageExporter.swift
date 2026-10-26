import BetterShotCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The formats offered by the editor's "Save as…" (requirements §3.3).
public enum ExportFormat: String, CaseIterable, Sendable {
    case png, jpeg, pdf

    public var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        case .pdf: "pdf"
        }
    }

    public var displayName: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .pdf: "PDF"
        }
    }

    public var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .pdf: .pdf
        }
    }
}

public enum ImageExporter {
    private static let jpegQuality = 0.9

    /// Encodes `image`. `pointScale` is pixels per point and only affects PDF page size.
    public static func data(for image: CGImage, format: ExportFormat, pointScale: CGFloat = 1) throws(SaveError) -> Data {
        switch format {
        case .png: try encode(image, as: UTType.png)
        case .jpeg: try encode(onWhite(image) ?? image, as: UTType.jpeg, properties: [kCGImageDestinationLossyCompressionQuality: jpegQuality])
        case .pdf: try pdf(image, pointScale: pointScale)
        }
    }

    // MARK: Private

    private static func encode(_ image: CGImage, as type: UTType, properties: [CFString: Any] = [:]) throws(SaveError) -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            throw .encodingFailed
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .encodingFailed }
        return output as Data
    }

    /// JPEG has no alpha channel; composite onto white so transparent areas don't turn black.
    private static func onWhite(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        return context.makeImage()
    }

    private static func pdf(_ image: CGImage, pointScale: CGFloat) throws(SaveError) -> Data {
        let scale = pointScale > 0 ? pointScale : 1
        var mediaBox = CGRect(x: 0, y: 0, width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        let output = NSMutableData()
        guard
            let consumer = CGDataConsumer(data: output),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw .encodingFailed }

        context.beginPDFPage(nil)
        context.draw(image, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
        return output as Data
    }
}
