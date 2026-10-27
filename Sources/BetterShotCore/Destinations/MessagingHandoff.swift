import Foundation

/// The chat apps an image can be handed to (requirements §4.9).
public enum MessagingApp: String, CaseIterable, Sendable {
    case whatsApp, telegram

    public var displayName: String {
        switch self {
        case .whatsApp: "WhatsApp"
        case .telegram: "Telegram"
        }
    }

    /// Known bundle identifiers of the desktop app, most common first (Telegram ships two native clients).
    public var bundleIdentifiers: [String] {
        switch self {
        case .whatsApp: ["net.whatsapp.WhatsApp"]
        case .telegram: ["ru.keepcoder.Telegram", "org.telegram.desktop"]
        }
    }

    public var webURL: URL {
        switch self {
        case .whatsApp: URL(string: "https://web.whatsapp.com")!
        case .telegram: URL(string: "https://web.telegram.org/a/")!
        }
    }
}

/// What to do after the image is on the clipboard: open the installed desktop app, or the provider's web client.
/// Either way nothing is uploaded by BetterShot, and the image goes alone, with no caption (requirements §4.9).
public enum MessagingHandoff: Equatable, Sendable {
    case openApp(bundleIdentifier: String)
    case openWeb(URL)

    /// `isInstalled` answers whether a desktop app with that bundle identifier is installed.
    public static func plan(for app: MessagingApp, isInstalled: (String) -> Bool) -> MessagingHandoff {
        if let installed = app.bundleIdentifiers.first(where: isInstalled) {
            return .openApp(bundleIdentifier: installed)
        }
        return .openWeb(app.webURL)
    }
}
