import AppKit

/// BetterShot is a menu-bar agent with no visible menu bar, but AppKit still needs a main menu so key
/// equivalents work: ⌘Z / ⇧⌘Z reach the editor canvas and ⌘C / ⌘V / ⌘A work in its text field.
@MainActor
enum MainMenu {
    static func install() {
        let menu = NSMenu()
        menu.addItem(submenuItem(title: "BetterShot") { appMenu in
            appMenu.addItem(withTitle: "Quit BetterShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        })
        menu.addItem(submenuItem(title: "Edit") { edit in
            edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
            let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
            redo.keyEquivalentModifierMask = [.command, .shift]
            edit.addItem(.separator())
            edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        })
        NSApp.mainMenu = menu
    }

    private static func submenuItem(title: String, populate: (NSMenu) -> Void) -> NSMenuItem {
        let item = NSMenuItem()
        let submenu = NSMenu(title: title)
        populate(submenu)
        item.submenu = submenu
        return item
    }
}
