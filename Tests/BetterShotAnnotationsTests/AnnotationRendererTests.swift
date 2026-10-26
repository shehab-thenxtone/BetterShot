import CoreGraphics
import Testing
@testable import BetterShotAnnotations

// MARK: Pixel helpers

private let white: [UInt8] = [255, 255, 255, 255]
private let red: [UInt8] = [255, 0, 0, 255]
private let pureRed = AnnotationColor(red: 1, green: 0, blue: 0)

/// RGBA8 pixels of an image, indexed from the top-left.
private struct PixelBuffer {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        buffer.withUnsafeMutableBytes { pointer in
            let context = CGContext(
                data: pointer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        bytes = buffer
    }

    func pixel(_ x: Int, _ y: Int) -> [UInt8] {
        let index = (y * width + x) * 4
        return Array(bytes[index..<index + 4])
    }
}

/// Builds an opaque image whose pixel (x, y) comes from `color`.
private func makeImage(width: Int, height: Int, color: (Int, Int) -> [UInt8]) -> CGImage {
    var buffer = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let rgba = color(x, y)
            let index = (y * width + x) * 4
            buffer[index..<index + 4] = ArraySlice(rgba)
        }
    }
    return buffer.withUnsafeMutableBytes { pointer in
        CGContext(
            data: pointer.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!.makeImage()!
    }
}

private func whiteImage(_ width: Int = 100, _ height: Int = 100) -> CGImage {
    makeImage(width: width, height: height) { _, _ in white }
}

private func render(_ base: CGImage, _ document: AnnotationDocument) -> PixelBuffer {
    PixelBuffer(AnnotationRenderer.flatten(base, with: document)!)
}

// MARK: Tests

struct AnnotationRendererTests {
    private let style = AnnotationStyle(color: pureRed, lineWeight: .medium)

    private func document(_ width: CGFloat = 100, _ height: CGFloat = 100) -> AnnotationDocument {
        AnnotationDocument(canvasSize: CGSize(width: width, height: height))
    }

    @Test func outputKeepsTheBaseImageSize() throws {
        let base = whiteImage(120, 80)
        let output = try #require(AnnotationRenderer.flatten(base, with: document(120, 80)))
        #expect(output.width == 120 && output.height == 80)
    }

    @Test func documentWithoutAnnotationsLeavesPixelsUntouched() {
        let base = makeImage(width: 8, height: 8) { x, y in [UInt8(x * 30), UInt8(y * 30), 7, 255] }
        let original = PixelBuffer(base)
        let output = render(base, document(8, 8))
        for (x, y) in [(0, 0), (3, 5), (7, 7)] {
            #expect(output.pixel(x, y) == original.pixel(x, y))
        }
    }

    @Test func documentCoordinatesHaveATopLeftOrigin() {
        let doc = document().adding(.rectangle(CGRect(x: 0, y: 0, width: 20, height: 20), isFilled: true), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(5, 5) == red)
        #expect(output.pixel(5, 95) == white)
        #expect(output.pixel(95, 5) == white)
    }

    @Test func documentCoordinatesAreScaledToTheImageSize() {
        // 50x50-point canvas over a 100x100-pixel image: a 10pt square becomes 20px.
        let doc = document(50, 50).adding(.rectangle(CGRect(x: 0, y: 0, width: 10, height: 10), isFilled: true), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(15, 15) == red)
        #expect(output.pixel(25, 25) == white)
    }

    @Test func outlinedRectangleLeavesItsInteriorAlone() {
        let doc = document().adding(.rectangle(CGRect(x: 10, y: 10, width: 60, height: 60), isFilled: false), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(40, 10) == red) // top edge
        #expect(output.pixel(40, 40) == white) // interior
    }

    @Test func ellipseStrokesItsEdgeButNotItsCenter() {
        let doc = document().adding(.ellipse(CGRect(x: 10, y: 10, width: 80, height: 80)), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(50, 50) == white)
        #expect(output.pixel(50, 10) != white) // top of the ellipse
    }

    @Test func laterAnnotationsDrawOverEarlierOnes() {
        let blue = AnnotationColor(red: 0, green: 0, blue: 1)
        let doc = document()
            .adding(.rectangle(CGRect(x: 0, y: 0, width: 40, height: 40), isFilled: true), style: style)
            .adding(.rectangle(CGRect(x: 20, y: 20, width: 40, height: 40), isFilled: true), style: style.updating(color: blue))
        let output = render(whiteImage(), doc)
        #expect(output.pixel(10, 10) == red)
        #expect(output.pixel(30, 30) == [0, 0, 255, 255]) // overlap: the later (blue) wins
    }

    @Test func arrowDrawsItsShaftAndTipButNothingElsewhere() {
        let doc = document().adding(.arrow(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 90, y: 50)), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(50, 50) != white) // shaft
        #expect(output.pixel(88, 50) != white) // tip
        #expect(output.pixel(50, 20) == white)
        #expect(output.pixel(5, 50) == white) // behind the tail
    }

    @Test func openArrowHeadStillDrawsTheShaft() {
        let openStyle = style.updating(arrowStyle: .open)
        let doc = document().adding(.arrow(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 90, y: 50)), style: openStyle)
        #expect(render(whiteImage(), doc).pixel(50, 50) != white)
    }

    @Test func lineStrokesAlongItsPath() {
        let doc = document().adding(.line(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 90, y: 50)), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(50, 50) == red)
        #expect(output.pixel(50, 70) == white)
    }

    @Test func penAndMarkerStrokeAlongTheirPoints() {
        let points = [CGPoint(x: 10, y: 20), CGPoint(x: 50, y: 20), CGPoint(x: 90, y: 20)]
        let pen = render(whiteImage(), document().adding(.pen(points: points), style: style))
        #expect(pen.pixel(50, 20) == red)

        let marker = render(whiteImage(), document().adding(.marker(points: points), style: style))
        #expect(marker.pixel(50, 20) != white)
        #expect(marker.pixel(50, 60) == white)
    }

    @Test func textHighlightFillsItsRectWithTheTranslucentColor() {
        let yellow = AnnotationColor(red: 1, green: 1, blue: 0, alpha: 0.5)
        let doc = document().adding(.textHighlight(CGRect(x: 10, y: 10, width: 50, height: 20)), style: style.updating(color: yellow))
        let output = render(whiteImage(), doc)
        let inside = output.pixel(30, 20)
        #expect(inside != white)
        #expect(inside[2] < 255) // blue channel reduced by the yellow tint
        #expect(output.pixel(30, 60) == white)
    }

    @Test func textDrawsInsideItsBoxOnly() {
        let base = whiteImage(200, 60)
        let black = AnnotationColor(red: 0, green: 0, blue: 0)
        let doc = document(200, 60).adding(.text("Hello", origin: CGPoint(x: 10, y: 10), fontSize: 24), style: style.updating(color: black))
        let output = render(base, doc)

        var inkInBox = 0
        var inkElsewhere = 0
        for y in 0..<60 {
            for x in 0..<200 where output.pixel(x, y) != white {
                if (10..<140).contains(x), (10..<45).contains(y) { inkInBox += 1 } else { inkElsewhere += 1 }
            }
        }
        #expect(inkInBox > 30)
        #expect(inkElsewhere == 0)
    }

    @Test func stepCounterDrawsAFilledBadge() {
        let doc = document().addingStep(at: CGPoint(x: 50, y: 50), style: style)
        let output = render(whiteImage(), doc)
        #expect(output.pixel(40, 50) == red) // inside the circle, clear of the digit
        #expect(output.pixel(50, 50) != red) // the digit is drawn over the centre
        #expect(output.pixel(50, 80) == white)
    }

    // MARK: Pixelate (privacy, requirements §4.6)

    private func noiseImage(_ size: Int) -> CGImage {
        makeImage(width: size, height: size) { x, y in
            [
                UInt8((x * 73 + y * 151 + (x * y) % 97 * 31) % 256),
                UInt8((y * 89 + x * 17 + (x + y) % 53 * 43) % 256),
                UInt8((x * 41 + y * 113 + (x * 7 + y * 3) % 61 * 29) % 256),
                255,
            ]
        }
    }

    @Test func pixelateReplacesTheRegionWithUniformBlocks() {
        let base = noiseImage(96)
        let doc = document(96, 96).adding(.pixelate(CGRect(x: 12, y: 12, width: 48, height: 48)), style: style)
        let output = render(base, doc)

        // 12pt blocks anchored at the region's top-left: every pixel in a block is identical.
        for blockY in 0..<4 {
            for blockX in 0..<4 {
                let originX = 12 + blockX * 12
                let originY = 12 + blockY * 12
                let first = output.pixel(originX, originY)
                for dy in 0..<12 {
                    for dx in 0..<12 {
                        #expect(output.pixel(originX + dx, originY + dy) == first)
                    }
                }
            }
        }
    }

    @Test func pixelateDestroysTheOriginalDetailAndLeavesTheRestAlone() {
        let base = noiseImage(96)
        let original = PixelBuffer(base)
        let doc = document(96, 96).adding(.pixelate(CGRect(x: 12, y: 12, width: 48, height: 48)), style: style)
        let output = render(base, doc)

        var changed = 0
        var distinct = Set<[UInt8]>()
        for y in 12..<60 {
            for x in 12..<60 {
                if output.pixel(x, y) != original.pixel(x, y) { changed += 1 }
                distinct.insert(output.pixel(x, y))
            }
        }
        #expect(changed > 48 * 48 * 8 / 10)
        #expect(distinct.count <= 16) // at most one colour per 12x12 block: the detail can't be recovered

        for (x, y) in [(5, 5), (80, 80), (70, 20), (20, 70)] {
            #expect(output.pixel(x, y) == original.pixel(x, y))
        }
    }

    @Test func pixelateOutsideTheImageIsIgnored() {
        let base = noiseImage(32)
        let original = PixelBuffer(base)
        let doc = document(32, 32).adding(.pixelate(CGRect(x: 500, y: 500, width: 40, height: 40)), style: style)
        let output = render(base, doc)
        #expect(output.pixel(10, 10) == original.pixel(10, 10))
    }
}
