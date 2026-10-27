import AppKit
import BetterShotCore
import BetterShotServices

/// Runs one screen recording from start to stop: choose what to record (an area, or the whole display with
/// Return), record to an MP4 with Pause and Stop controls, then hand the finished file on.
@MainActor
final class RecordingController {
    enum State { case idle, recording, paused }

    private(set) var state: State = .idle
    var isActive: Bool { state != .idle }

    /// Called with the finished file after a normal stop.
    var onFinished: (@MainActor (RecordingResult) -> Void)?

    private let recorder = ScreenRecorder()
    private let overlay = SelectionOverlayController()
    private let hud = RecordingHUDController()
    private let directory: URL
    private var isStarting = false

    init(directory: URL = RecordingsFolder.defaultDirectory) {
        self.directory = directory
    }

    /// Starts recording, or stops if one is already running (so the menu item and a hotkey can be the same control).
    func toggle() async {
        if isActive { await stop() } else { await start() }
    }

    func start() async {
        guard !isActive, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        guard ScreenRecordingPermission.isGranted else {
            ScreenRecordingPermission.request()
            CaptureAlerts.presentPermissionDenied()
            return
        }
        guard let request = CaptureRequestFactory.request(for: await overlay.run(mode: .recording)) else { return }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await recorder.start(request, to: RecordingsFolder.url(forNewRecordingIn: directory))
        } catch {
            CaptureAlerts.presentInfo(title: "Couldn't start recording", message: error.localizedDescription, style: .warning)
            return
        }

        state = .recording
        hud.show(
            elapsed: { [weak self] in self?.recorder.elapsedSeconds ?? 0 },
            onPauseResume: { [weak self] in self?.togglePause() },
            onStop: { [weak self] in Task { await self?.stop() } }
        )
    }

    func togglePause() {
        switch state {
        case .recording:
            recorder.pause()
            state = .paused
        case .paused:
            recorder.resume()
            state = .recording
        case .idle:
            return
        }
        hud.setPaused(state == .paused)
    }

    /// Stops and closes the file. `deliver: false` skips `onFinished` for callers that handle the file themselves
    /// (saving on quit).
    @discardableResult
    func stop(deliver: Bool = true) async -> RecordingResult? {
        guard isActive else { return nil }
        state = .idle
        hud.hide()

        do {
            let result = try await recorder.stop()
            if deliver { onFinished?(result) }
            return result
        } catch {
            CaptureAlerts.presentInfo(title: "Recording failed", message: error.localizedDescription, style: .warning)
            return nil
        }
    }
}
