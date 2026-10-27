import AppKit
import BetterShotCore
import SwiftUI

/// Shows the single Preferences window, reusing it if it's already open.
@MainActor
final class PreferencesWindowController {
    private let model: SettingsModel
    private let folderStore: any SaveFolderStoring
    private let destinations: DestinationsCenter
    private var window: NSWindow?

    init(model: SettingsModel, folderStore: any SaveFolderStoring, destinations: DestinationsCenter) {
        self.model = model
        self.folderStore = folderStore
        self.destinations = destinations
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
        window.contentView = NSHostingView(rootView: PreferencesView(model: model, folderStore: folderStore, destinations: destinations))
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
