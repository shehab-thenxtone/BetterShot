import AppKit
import BetterShotCore
import BetterShotServices
import Observation
import OSLog
import SwiftUI

/// Scrolling Capture (requirements §3.1 item 6): you pick an area, BetterShot scrolls the content under it step by
/// step, captures each step and stitches them into one long image (vertical or horizontal). The decisions live in
/// `ScrollCaptureEngine`; this class provides the real screen, the permissions, the HUD and the hand-off.
@MainActor
final class ScrollCaptureController {
    private let capturer: any ScreenCapturer
    private let deliver: @MainActor (CaptureResult) -> Void
    private let overlay = SelectionOverlayController()
    private let driver = ScrollDriver()
    private let hud = ScrollCaptureHUDController()
    private let logger = Logger(subsystem: "com.bettershot.app", category: "scroll-capture")

    private(set) var isActive = false

    init(capturer: any ScreenCapturer, deliver: @escaping @MainActor (CaptureResult) -> Void) {
        self.capturer = capturer
        self.deliver = deliver
    }

    func run(axis: ScrollAxis) async {
        guard !isActive else { return }
        isActive = true
        defer { isActive = false }

        guard ScreenRecordingPermission.isGranted else {
            ScreenRecordingPermission.request()
            CaptureAlerts.presentPermissionDenied()
            return
        }
        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.request()
            CaptureAlerts.presentAccessibilityNeeded()
            return
        }

        let outcome = await overlay.run(mode: .area)
        guard
            case .area(_, let globalRect) = outcome,
            let request = CaptureRequestFactory.request(for: outcome)
        else { return }

        let originalCursor = driver.cursorLocation()
        let stop = StopFlag()
        hud.show(avoiding: globalRect, onStop: { stop.set() })
        defer {
            hud.hide()
            if let originalCursor { driver.moveCursor(to: originalCursor) }
        }

        let surface = SystemScrollingSurface(
            capturer: capturer, driver: driver, request: request, axis: axis,
            target: Self.eventLocation(forAppKitRect: globalRect)
        )
        let extent = Int((axis == .vertical ? globalRect.height : globalRect.width).rounded())

        do {
            let builder = try await ScrollCaptureEngine.capture(
                from: surface, axis: axis, extent: extent,
                shouldStop: { stop.isSet },
                onProgress: { [hud] count in Task { @MainActor in hud.update(frameCount: count) } }
            )
            finish(with: builder, axis: axis)
        } catch {
            logger.error("Scrolling capture failed: \(error.localizedDescription, privacy: .public)")
            CaptureAlerts.presentInfo(title: "Scrolling capture failed", message: error.localizedDescription, style: .warning)
        }
    }

    private func finish(with builder: ScrollStitchBuilder, axis: ScrollAxis) {
        guard builder.frameCount > 1 else {
            CaptureAlerts.presentInfo(
                title: "Nothing scrolled",
                message: "The selected area didn't move when scrolled \(axis == .vertical ? "vertically" : "horizontally"). Select an area with scrollable content, or use the other direction.",
                style: .warning
            )
            return
        }
        guard let image = builder.result.makeImage() else {
            CaptureAlerts.presentInfo(title: "Couldn't finish", message: "The stitched image couldn't be created.", style: .warning)
            return
        }
        deliver(CaptureResult(image: image))
    }

    /// Centre of an AppKit-space rect (bottom-left origin) as a CoreGraphics event location (top-left origin).
    private static func eventLocation(forAppKitRect rect: CGRect) -> CGPoint {
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        return CGPoint(x: rect.midX, y: primaryHeight - rect.midY)
    }
}

// MARK: Real screen

/// The actual screen behind the engine: scrolls with posted wheel events and captures with ScreenCaptureKit.
private struct SystemScrollingSurface: ScrollingSurface {
    let capturer: any ScreenCapturer
    let driver: ScrollDriver
    let request: CaptureRequest
    let axis: ScrollAxis
    let target: CGPoint

    func scroll(by pixels: Int) async {
        driver.scroll(by: pixels, axis: axis, at: target)
    }

    /// Waits for the scroll animation to finish: captures until two consecutive frames are identical.
    func settledFrame() async throws -> PixelFrame {
        try await Task.sleep(for: .milliseconds(250))
        var previous = try await frame()
        for _ in 0..<8 {
            try await Task.sleep(for: .milliseconds(120))
            let next = try await frame()
            if next == previous { return next }
            previous = next
        }
        return previous
    }

    private func frame() async throws -> PixelFrame {
        let result = try await capturer.capture(request)
        guard let frame = PixelFrame(image: result.image) else {
            throw CaptureError.failed("A frame couldn't be read.")
        }
        return frame
    }
}

/// Set from the HUD's Stop button (main actor), read by the engine from whichever executor it runs on.
private final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
}

// MARK: HUD

@MainActor
@Observable
final class ScrollCaptureHUDModel {
    var frameCount = 0
}

/// A small "Scrolling… N frames" strip with a Stop button. It sits outside the selected area so it never
/// intercepts the scroll events that go to the content underneath.
@MainActor
final class ScrollCaptureHUDController {
    private let model = ScrollCaptureHUDModel()
    private var panel: NSPanel?

    func show(avoiding captureRect: CGRect, onStop: @escaping @MainActor () -> Void) {
        hide()
        model.frameCount = 0

        let size = CGSize(width: 240, height: 60)
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: ScrollCaptureHUDView(model: model, onStop: onStop))
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visible = NSScreen.underCursor?.visibleFrame ?? .zero
        var origin = DockPlacement.bottomCenter(size: size, in: visible, margin: 24)
        if CGRect(origin: origin, size: size).intersects(captureRect) {
            origin = CGPoint(x: origin.x, y: visible.maxY - size.height - 24) // the bottom is taken: use the top
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func update(frameCount: Int) {
        model.frameCount = frameCount
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ScrollCaptureHUDView: View {
    let model: ScrollCaptureHUDModel
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text(model.frameCount <= 1 ? "Scrolling…" : "Scrolling… \(model.frameCount) frames")
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
            Button("Stop", action: onStop)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Stop and keep what's captured so far")
        }
        .padding(.horizontal, 14)
        .frame(width: 224, height: 44)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .padding(8)
        .accessibilityElement(children: .contain)
    }
}
