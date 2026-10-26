import CoreGraphics
import Testing
@testable import BetterShotAnnotations

struct EditorStateTests {
    private let red: [UInt8] = [255, 0, 0, 255]
    private let blue: [UInt8] = [0, 0, 255, 255]
    private let clear: [UInt8] = [0, 0, 0, 0]

    @Test func canvasIsMeasuredInPointsFromThePointScale() {
        let state = EditorState(image: TestImage.solid(width: 200, height: 100, red), pointScale: 2)
        #expect(state.document.canvasSize == CGSize(width: 100, height: 50))
        #expect(state.pointScale == 2)
    }

    @Test func nonPositiveScaleFallsBackToOne() {
        let state = EditorState(image: TestImage.solid(width: 40, height: 20, red), pointScale: 0)
        #expect(state.document.canvasSize == CGSize(width: 40, height: 20))
    }

    @Test func stateEqualityFollowsImageIdentityAndDocument() {
        let image = TestImage.solid(width: 10, height: 10, red)
        let state = EditorState(image: image)
        #expect(state == state)
        #expect(state != EditorState(image: image)) // same pixels, but a different editing session
        #expect(state.with(document: state.document) == state)
        #expect(state.with(document: state.document.adding(.ellipse(.zero), style: AnnotationStyle())) != state)
    }

    @Test func croppingKeepsTheRegionShiftsAnnotationsAndShrinksTheCanvas() throws {
        // Left half red, right half blue; 2 pixels per point.
        let image = TestImage.make(width: 100, height: 80) { x, _ in x < 50 ? red : blue }
        var state = EditorState(image: image, pointScale: 2)
        state = state.with(document: state.document.adding(.rectangle(CGRect(x: 30, y: 10, width: 10, height: 10), isFilled: true), style: AnnotationStyle()))

        let cropped = try #require(state.cropped(to: CGRect(x: 25, y: 5, width: 25, height: 20)))

        let result = cropped.baseImage.cgImage
        #expect(result.width == 50 && result.height == 40)
        #expect(TestImage.pixel(result, 0, 0) == blue)
        #expect(cropped.document.canvasSize == CGSize(width: 25, height: 20))
        #expect(cropped.document.annotations[0].kind == .rectangle(CGRect(x: 5, y: 5, width: 10, height: 10), isFilled: true))
        #expect(cropped.pointScale == 2)
    }

    @Test func croppingOutsideTheCanvasFails() {
        let state = EditorState(image: TestImage.solid(width: 50, height: 50, red))
        #expect(state.cropped(to: CGRect(x: 100, y: 100, width: 10, height: 10)) == nil)
    }

    @Test func croppingBeyondTheEdgesIsClamped() throws {
        let state = EditorState(image: TestImage.solid(width: 50, height: 50, red))
        let cropped = try #require(state.cropped(to: CGRect(x: 25, y: 25, width: 500, height: 500)))
        #expect(cropped.baseImage.cgImage.width == 25 && cropped.baseImage.cgImage.height == 25)
    }

    @Test func appendingPlacesTheNewImageOnTheRightAlignedToTheTop() throws {
        let left = TestImage.solid(width: 40, height: 40, red)
        let right = TestImage.solid(width: 20, height: 20, blue)
        var state = EditorState(image: left)
        state = state.with(document: state.document.adding(.ellipse(CGRect(x: 1, y: 2, width: 3, height: 4)), style: AnnotationStyle()))

        let merged = try #require(state.appendingRight(right))

        let image = merged.baseImage.cgImage
        #expect(image.width == 60 && image.height == 40)
        #expect(TestImage.pixel(image, 5, 5) == red)
        #expect(TestImage.pixel(image, 45, 5) == blue) // new image, top aligned
        #expect(TestImage.pixel(image, 45, 35) == clear) // below the shorter image: transparent
        #expect(merged.document.canvasSize == CGSize(width: 60, height: 40))
        #expect(merged.document.annotations == state.document.annotations) // existing annotations stay put
    }

    @Test func appendingATallerImageGrowsTheCanvasHeightAndKeepsTheBaseAtTheTop() throws {
        let state = EditorState(image: TestImage.solid(width: 20, height: 20, red))
        let merged = try #require(state.appendingRight(TestImage.solid(width: 20, height: 60, blue)))
        let image = merged.baseImage.cgImage
        #expect(image.width == 40 && image.height == 60)
        #expect(TestImage.pixel(image, 5, 5) == red)
        #expect(TestImage.pixel(image, 5, 50) == clear)
    }

    @Test func flatteningBakesAnnotationsIntoTheBaseImage() throws {
        var state = EditorState(image: TestImage.solid(width: 50, height: 50, [255, 255, 255, 255]))
        let style = AnnotationStyle(color: AnnotationColor(red: 1, green: 0, blue: 0))
        state = state.with(document: state.document.adding(.rectangle(CGRect(x: 0, y: 0, width: 20, height: 20), isFilled: true), style: style))

        let flat = try #require(state.flattened())

        #expect(TestImage.pixel(flat, 5, 5) == red)
        #expect(TestImage.pixel(flat, 40, 40) == [255, 255, 255, 255])
    }
}
