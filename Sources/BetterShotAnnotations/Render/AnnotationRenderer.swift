import CoreGraphics
import CoreText
import Foundation

/// Flattens an `AnnotationDocument` onto its base image. This is the only place pixels are produced, and it is
/// where redaction becomes irreversible: `.pixelate` overwrites the underlying pixels, so nothing recoverable
/// survives in the output (requirements §4.6).
public enum AnnotationRenderer {
    /// Mosaic cell size in document points.
    static let pixelateBlockPoints: CGFloat = 12

    /// Returns a new image the size of `base` with every annotation drawn in order, or nil if a drawing
    /// context couldn't be created. The document may use a different point size than the image's pixels;
    /// it is scaled to fit.
    public static func flatten(_ base: CGImage, with document: AnnotationDocument) -> CGImage? {
        guard base.width > 0, base.height > 0, document.canvasSize.width > 0 else { return nil }
        guard let context = makeContext(width: base.width, height: base.height) else { return nil }

        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))

        let space = CanvasSpace(scale: CGFloat(base.width) / document.canvasSize.width, pixelHeight: CGFloat(base.height))
        for annotation in document.annotations {
            context.saveGState()
            draw(annotation, in: context, space: space)
            context.restoreGState()
        }
        return context.makeImage()
    }

    // MARK: Coordinates

    /// Converts document points (top-left origin) to context pixels (bottom-left origin).
    private struct CanvasSpace {
        let scale: CGFloat
        let pixelHeight: CGFloat

        func point(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scale, y: pixelHeight - point.y * scale)
        }

        func rect(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX * scale, y: pixelHeight - rect.maxY * scale, width: rect.width * scale, height: rect.height * scale)
        }

        /// Pixel rect keeping the top-left origin, which is what `CGImage.cropping(to:)` expects.
        func topLeftRect(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
        }
    }

    /// An sRGB RGBA bitmap context, shared with `ImageOperations`.
    static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    // MARK: Drawing

    private static func draw(_ annotation: Annotation, in context: CGContext, space: CanvasSpace) {
        let color = annotation.style.color.cgColor
        let strokeWidth = annotation.style.lineWeight.points * space.scale
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.kind {
        case .rectangle(let rect, let isFilled):
            if isFilled { context.fill(space.rect(rect)) } else { context.stroke(space.rect(rect)) }
        case .ellipse(let rect):
            context.strokeEllipse(in: space.rect(rect))
        case .line(let from, let to):
            strokePolyline([space.point(from), space.point(to)], in: context)
        case .arrow(let from, let to):
            drawArrow(from: space.point(from), to: space.point(to), style: annotation.style, strokeWidth: strokeWidth, in: context)
        case .text(let string, let origin, let fontSize):
            drawText(string, at: space.point(origin), fontSize: fontSize * space.scale, color: color, in: context)
        case .pixelate(let rect):
            pixelate(space.topLeftRect(rect), blockSize: pixelateBlockPoints * space.scale, in: context)
        case .stepCounter(let center, let number):
            drawStepCounter(number, at: space.point(center), style: annotation.style, scale: space.scale, in: context)
        case .marker(let points):
            context.setLineWidth(strokeWidth * 3) // highlighter-wide stroke
            strokePolyline(points.map(space.point), in: context)
        case .pen(let points):
            strokePolyline(points.map(space.point), in: context)
        case .textHighlight(let rect):
            context.fill(space.rect(rect))
        }
    }

    private static func strokePolyline(_ points: [CGPoint], in context: CGContext) {
        guard let first = points.first else { return }
        if points.count == 1 { // a single dab: a zero-length line draws a dot with the round cap
            context.move(to: first)
            context.addLine(to: first)
        } else {
            context.addLines(between: points)
        }
        context.strokePath()
    }

    private static func drawArrow(from tail: CGPoint, to tip: CGPoint, style: AnnotationStyle, strokeWidth: CGFloat, in context: CGContext) {
        let length = hypot(tip.x - tail.x, tip.y - tail.y)
        guard length > 0 else { return }

        let angle = atan2(tip.y - tail.y, tip.x - tail.x)
        let spread = CGFloat.pi / 7
        let headLength = min(length, max(12, strokeWidth * 4))
        let left = CGPoint(x: tip.x - headLength * cos(angle - spread), y: tip.y - headLength * sin(angle - spread))
        let right = CGPoint(x: tip.x - headLength * cos(angle + spread), y: tip.y - headLength * sin(angle + spread))

        switch style.arrowStyle {
        case .solid:
            // End the shaft inside the head so the tip stays sharp.
            let shaftEnd = CGPoint(x: tip.x - headLength * 0.8 * cos(angle), y: tip.y - headLength * 0.8 * sin(angle))
            strokePolyline([tail, shaftEnd], in: context)
            context.move(to: tip)
            context.addLine(to: left)
            context.addLine(to: right)
            context.closePath()
            context.fillPath()
        case .open:
            strokePolyline([tail, tip], in: context)
            strokePolyline([left, tip, right], in: context)
        }
    }

    private static func drawText(_ string: String, at origin: CGPoint, fontSize: CGFloat, color: CGColor, in context: CGContext) {
        let font = TextLayout.font(size: fontSize)
        var top = origin.y // bottom-left coordinates: lines go downwards, so y decreases
        context.textMatrix = .identity
        for text in TextLayout.lines(of: string) {
            let line = TextLayout.ctLine(text, font: font, color: color)
            context.textPosition = CGPoint(x: origin.x, y: top - CTFontGetAscent(font))
            CTLineDraw(line, context)
            top -= TextLayout.lineHeight(of: font)
        }
    }

    private static func drawStepCounter(_ number: Int, at center: CGPoint, style: AnnotationStyle, scale: CGFloat, in context: CGContext) {
        let diameter = AnnotationKind.stepCounterDiameter * scale
        context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))

        let textColor = style.color.luminance > 0.7 ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1)
        let font = TextLayout.font(size: diameter * 0.55, isBold: true)
        let line = TextLayout.ctLine(String(number), font: font, color: textColor)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: center.x - TextLayout.width(of: line) / 2, y: center.y - (ascent - descent) / 2)
        CTLineDraw(line, context)
    }

    // MARK: Redaction

    /// Replaces `region` (pixels, top-left origin) with a mosaic of `blockSize`-pixel cells, anchored at the
    /// region's top-left. Each cell becomes one flat colour, so the original detail is gone from the output.
    private static func pixelate(_ region: CGRect, blockSize: CGFloat, in context: CGContext) {
        let imageBounds = CGRect(x: 0, y: 0, width: context.width, height: context.height)
        let target = region.integral.intersection(imageBounds)
        let block = max(2, blockSize.rounded())
        guard !target.isNull, target.width >= 1, target.height >= 1 else { return }
        guard let snapshot = context.makeImage(), let crop = snapshot.cropping(to: target) else { return }

        let columns = Int((target.width / block).rounded(.up))
        let rows = Int((target.height / block).rounded(.up))
        guard let small = makeContext(width: columns, height: rows) else { return }
        small.interpolationQuality = .high
        small.draw(crop, in: CGRect(x: 0, y: 0, width: columns, height: rows)) // downscale = average colour per cell
        guard let mosaic = small.makeImage() else { return }

        let destination = CGRect(
            x: target.minX,
            y: imageBounds.height - target.minY - CGFloat(rows) * block,
            width: CGFloat(columns) * block,
            height: CGFloat(rows) * block
        )
        context.clip(to: CGRect(x: target.minX, y: imageBounds.height - target.maxY, width: target.width, height: target.height))
        context.interpolationQuality = .none // hard cell edges
        context.draw(mosaic, in: destination)
    }
}
