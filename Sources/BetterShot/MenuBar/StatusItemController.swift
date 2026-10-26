import AppKit
import BetterShotCore

/// Owns the menu-bar icon and its dropdown (layout mirrors docs/reference/menu-dropdown.png).
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    /// Live state the menu reflects each time it opens.
    struct MenuState {
        var desktopIconsHidden: Bool
        var canRestoreRecentlyClosed: Bool
    }

    private unowned let handler: any AppCommandHandler
    private var hotkeys: HotkeyBindings
    private let state: @MainActor () -> MenuState

    init(handler: any AppCommandHandler, hotkeys: HotkeyBindings, state: @escaping @MainActor () -> MenuState) {
        self.handler = handler
        self.hotkeys = hotkeys
        self.state = state
        super.init()
        configureButton()
        statusItem.menu = buildMenu()
    }

    /// Re-labels the menu's shortcuts after the user remaps them in Preferences.
    func updateHotkeys(_ hotkeys: HotkeyBindings) {
        self.hotkeys = hotkeys
        statusItem.menu = buildMenu()
    }

    private func configureButton() {
        let button = statusItem.button
        button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "BetterShot")
    }

    // MARK: Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false // `menuNeedsUpdate` decides which items are enabled
        for mode in CaptureMode.allCases {
            menu.addItem(item(for: .capture(mode)))
        }
        menu.addItem(.separator())
        menu.addItem(item(for: .toggleHideDesktopIcons))
        menu.addItem(.separator())
        menu.addItem(item(for: .openFile))
        menu.addItem(item(for: .pinToScreen))
        menu.addItem(item(for: .restoreRecentlyClosed))
        menu.addItem(.separator())
        menu.addItem(item(for: .about))
        menu.addItem(item(for: .checkForUpdates))
        menu.addItem(.separator())
        menu.addItem(item(for: .preferences))
        menu.addItem(.separator())
        menu.addItem(item(for: .quit))
        return menu
    }

    private func item(for command: AppCommand) -> NSMenuItem {
        let presentation = command.presentation(hotkeys: hotkeys)
        let item = NSMenuItem(title: presentation.title, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = CommandBox(command)
        if let symbol = presentation.symbolName {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: presentation.title)
        }
        if let shortcut = presentation.shortcut {
            item.keyEquivalent = shortcut.key
            item.keyEquivalentModifierMask = shortcut.modifiers.eventModifierFlags
        }
        return item
    }

    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? CommandBox else { return }
        handler.perform(box.command)
    }
}

extension StatusItemController: NSMenuDelegate {
    /// Hide Desktop Icons shows a checkmark while icons are hidden; Restore is disabled with nothing to restore.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let current = state()
        for item in menu.items {
            guard let box = item.representedObject as? CommandBox else { continue }
            switch box.command {
            case .toggleHideDesktopIcons: item.state = current.desktopIconsHidden ? .on : .off
            case .restoreRecentlyClosed: item.isEnabled = current.canRestoreRecentlyClosed
            default: break
            }
        }
    }
}

/// `representedObject` must be an object; this boxes the enum.
private final class CommandBox {
    let command: AppCommand
    init(_ command: AppCommand) { self.command = command }
}

private extension KeyShortcut.Modifiers {
    var eventModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.shift) { flags.insert(.shift) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        return flags
    }
}
