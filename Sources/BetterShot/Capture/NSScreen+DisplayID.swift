import AppKit

extension NSScreen {
    /// The CoreGraphics display ID ScreenCaptureKit uses to identify this screen.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }

    static func screen(withDisplayID id: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == id }
    }

    /// The display containing the mouse pointer, falling back to the main display.
    static var underCursor: NSScreen? {
        let cursor = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(cursor) } ?? main ?? screens.first
    }
}
