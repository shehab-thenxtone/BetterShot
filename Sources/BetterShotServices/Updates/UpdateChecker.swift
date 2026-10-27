import BetterShotCore
import Foundation

public enum UpdateCheckResult: Equatable, Sendable {
    case upToDate(current: AppVersion)
    case available(AvailableUpdate)
}

public enum UpdateCheckError: LocalizedError, Equatable {
    case notConfigured
    case unknownCurrentVersion
    case unreadableFeed

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "Update checking isn't set up in this build of BetterShot."
        case .unknownCurrentVersion: "This copy of BetterShot has no version number, so it can't be compared. Use the packaged app."
        case .unreadableFeed: "The update service returned something BetterShot couldn't read."
        }
    }
}

/// Manual "Check for Updates…": asks a release feed for the newest version and compares it with this one.
/// Nothing is downloaded or installed; the user is pointed at the release page.
public struct UpdateChecker: Sendable {
    private let feedURL: URL
    private let currentVersion: AppVersion
    private let transport: any HTTPTransport

    public init(feedURL: URL, currentVersion: AppVersion, transport: any HTTPTransport = URLSessionTransport()) {
        self.feedURL = feedURL
        self.currentVersion = currentVersion
        self.transport = transport
    }

    public func check() async throws -> UpdateCheckResult {
        var request = URLRequest(url: feedURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BetterShot/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let data = try await transport.sendExpectingSuccess(request)
        guard let latest = UpdateFeed.release(from: data) else { throw UpdateCheckError.unreadableFeed }
        return latest.version > currentVersion ? .available(latest) : .upToDate(current: currentVersion)
    }

    /// The feed URL from `BETTERSHOT_UPDATE_FEED_URL` or Info.plist `BetterShotUpdateFeedURL` (the environment
    /// wins). Only https is accepted, so a check can't be pointed at a plain-http or local-file source.
    public static func feedURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        for candidate in [environment["BETTERSHOT_UPDATE_FEED_URL"], infoDictionary?["BetterShotUpdateFeedURL"] as? String] {
            if let text = candidate?.trimmingCharacters(in: .whitespaces), let url = URL(string: text), url.scheme == "https" {
                return url
            }
        }
        return nil
    }

    /// The running app's version, from the bundle (`CFBundleShortVersionString`); nil outside a packaged app.
    public static func currentVersion(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> AppVersion? {
        (infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    }
}
