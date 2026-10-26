import AppKit
import BetterShotCore
import BetterShotServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Strong references for the app's lifetime; nothing here is torn down before quit.
    private var settingsModel: SettingsModel?
    private var desktopIcons: DesktopIcons?
    private var postCaptureFlow: PostCaptureFlow?
    private var textCaptureFlow: TextCaptureFlow?
    private var editorPresenter: EditorPresenter?
    private var pinManager: PinManager?
    private var resultBar: ResultBarController?
    private var preferences: PreferencesWindowController?
    private var router: AppCommandRouter?
    private var hotkeyController: HotkeyController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install()

        // Composition root.
        let model = SettingsModel(store: UserDefaultsSettingsStore())
        let folderStore = UserDefaultsSaveFolderStore()
        let recentlyClosed = RecentlyClosedStore()
        let desktopIcons = DesktopIcons.system
        let toast = ToastController()
        let actions = ResultActions(folderStore: folderStore, settings: { model.settings }, recentlyClosed: recentlyClosed)
        let flow = PostCaptureFlow(actions: actions, settings: { model.settings })
        let coordinator = CaptureCoordinator(
            capturer: ScreenCaptureKitCapturer(),
            previousAreaStore: UserDefaultsPreviousAreaStore(),
            deliver: { flow.present($0) }
        )
        let ocr = VisionOCRProvider()
        let textCapture = TextCaptureFlow(ocr: ocr, toast: toast)
        coordinator.recognizeText = { await textCapture.run(on: $0) }

        let countdown = CountdownController()
        coordinator.countdown = { await countdown.run(seconds: $0) }
        coordinator.selfTimerSeconds = { model.settings.selfTimerDelay.seconds }

        let editor = EditorPresenter(stylesStore: UserDefaultsToolStylesStore(), ocr: ocr, folderStore: folderStore, settings: { model.settings })
        let pins = PinManager(actions: actions)
        let resultBar = ResultBarController(pins: pins, actions: actions)

        // Wiring between surfaces: capture → popup → (editor | pin) → result bar → (pin | editor).
        flow.openEditor = { editor.open(image: $0) }
        flow.pinImage = { resultBar.show(image: $0, startPinned: true) }
        pins.openEditor = { editor.open(image: $0) }
        editor.onDone = { resultBar.show(image: $0, startPinned: false) }
        editor.onDiscard = { actions.recordClosed($0) }
        editor.captureForMerge = { mode in await coordinator.captureImage(mode)?.image }

        let preferences = PreferencesWindowController(model: model, folderStore: folderStore)
        let router = AppCommandRouter(
            captureCoordinator: coordinator,
            actions: AppCommandRouter.Actions(
                showPreferences: { preferences.show() },
                pinFromFile: {
                    if let image = ImageFiles.choose(message: "Choose an image to pin to the screen") {
                        resultBar.show(image: image, startPinned: true)
                    }
                },
                openFile: {
                    if let loaded = ImageFiles.chooseWithScale(message: "Choose an image to open in the editor") {
                        editor.open(image: loaded.image, pointScale: loaded.pointScale)
                    }
                },
                restoreRecentlyClosed: {
                    if let image = recentlyClosed.take() {
                        flow.present(CaptureResult(image: image))
                    } else {
                        toast.show("Nothing to restore", symbol: "arrow.uturn.backward")
                    }
                },
                toggleDesktopIcons: { desktopIcons.setHidden(!desktopIcons.areHidden) },
                afterCapture: {
                    // Hiding is temporary unless the user chose to keep icons hidden.
                    if desktopIcons.areHidden, !model.settings.keepsDesktopIconsHidden { desktopIcons.setHidden(false) }
                }
            )
        )
        let statusItem = StatusItemController(
            handler: router,
            hotkeys: model.settings.hotkeys,
            state: { .init(desktopIconsHidden: desktopIcons.areHidden, canRestoreRecentlyClosed: recentlyClosed.hasItem) }
        )
        let hotkeys = HotkeyController(handler: router)

        settingsModel = model
        self.desktopIcons = desktopIcons
        postCaptureFlow = flow
        textCaptureFlow = textCapture
        editorPresenter = editor
        pinManager = pins
        self.resultBar = resultBar
        self.preferences = preferences
        self.router = router
        statusItemController = statusItem
        hotkeyController = hotkeys

        model.onChange = { [weak self] old, new in self?.settingsChanged(from: old, to: new) }

        reportUnavailable(hotkeys.apply(model.settings.hotkeys))
        syncLaunchAtLoginWithSystem(model)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave the user's desktop bare unless they asked for the icons to stay hidden.
        guard let desktopIcons, desktopIcons.areHidden, settingsModel?.settings.keepsDesktopIconsHidden == false else { return }
        desktopIcons.setHidden(false)
    }

    // MARK: Reacting to settings

    private func settingsChanged(from old: AppSettings, to new: AppSettings) {
        if old.hotkeys != new.hotkeys {
            statusItemController?.updateHotkeys(new.hotkeys)
            reportUnavailable(hotkeyController?.apply(new.hotkeys) ?? [])
        }
        if old.launchesAtLogin != new.launchesAtLogin {
            applyLaunchAtLogin(new.launchesAtLogin)
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
        } catch {
            // Revert the toggle so Preferences reflects reality (e.g. running outside a .app bundle).
            settingsModel?.update { $0.updating(launchesAtLogin: !enabled) }
            CaptureAlerts.presentInfo(
                title: "Couldn't change launch at login",
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    /// The user can also toggle the login item in System Settings; trust the system's answer at launch.
    private func syncLaunchAtLoginWithSystem(_ model: SettingsModel) {
        let systemValue = LaunchAtLogin.isEnabled
        if model.settings.launchesAtLogin != systemValue {
            model.update { $0.updating(launchesAtLogin: systemValue) }
        }
    }

    private func reportUnavailable(_ failed: [KeyShortcut]) {
        guard !failed.isEmpty else { return }
        let list = failed.map(\.displayString).joined(separator: ", ")
        CaptureAlerts.presentInfo(
            title: "Some shortcuts are unavailable",
            message: "\(list) couldn't be registered because another app is using it. Choose a different shortcut in Preferences → Shortcuts.",
            style: .warning
        )
    }
}
