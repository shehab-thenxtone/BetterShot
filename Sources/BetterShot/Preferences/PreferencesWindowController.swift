import AppKit
import BetterShotCore
import SwiftUI

/// Shows the single Preferences window, reusing it if it's already open.
@MainActor
final class PreferencesWindowController {
    private let model: SettingsModel
    private let folderStore: any SaveFolderStoring
    private var window: NSWindow?

    init(model: SettingsModel, folderStore: any SaveFolderStoring) {
        self.model = model
        self.folderStore = folderStore
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BetterShot Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView(model: model, folderStore: folderStore))
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
