import AppKit
import BetterShotCore
import BetterShotServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Strong references for the app's lifetime; nothing here is torn down before quit.
    private var settingsModel: SettingsModel?
    private var postCaptureFlow: PostCaptureFlow?
    private var editorPresenter: EditorPresenter?
    private var preferences: PreferencesWindowController?
    private var router: AppCommandRouter?
    private var hotkeyController: HotkeyController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install()

        // Composition root.
        let model = SettingsModel(store: UserDefaultsSettingsStore())
        let folderStore = UserDefaultsSaveFolderStore()
        let flow = PostCaptureFlow(folderStore: folderStore, settings: { model.settings })
        let coordinator = CaptureCoordinator(
            capturer: ScreenCaptureKitCapturer(),
            previousAreaStore: UserDefaultsPreviousAreaStore(),
            deliver: { flow.present($0) }
        )
        let editor = EditorPresenter(stylesStore: UserDefaultsToolStylesStore(), folderStore: folderStore, settings: { model.settings })
        flow.openEditor = { editor.open(image: $0) }
        editor.onDone = { flow.present(CaptureResult(image: $0), opensEditorIfConfigured: false) }
        editor.captureForMerge = { mode in await coordinator.captureImage(mode)?.image }

        let preferences = PreferencesWindowController(model: model, folderStore: folderStore)
        let router = AppCommandRouter(captureCoordinator: coordinator, showPreferences: { preferences.show() })
        let statusItem = StatusItemController(handler: router, hotkeys: model.settings.hotkeys)
        let hotkeys = HotkeyController(handler: router)

        settingsModel = model
        postCaptureFlow = flow
        editorPresenter = editor
        self.preferences = preferences
        self.router = router
        statusItemController = statusItem
        hotkeyController = hotkeys

        model.onChange = { [weak self] old, new in self?.settingsChanged(from: old, to: new) }

        reportUnavailable(hotkeys.apply(model.settings.hotkeys))
        syncLaunchAtLoginWithSystem(model)
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
