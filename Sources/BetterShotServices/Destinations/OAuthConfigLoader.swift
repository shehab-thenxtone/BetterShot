import BetterShotCore
import Foundation

/// Reads the app's OAuth client IDs from configuration, never from source (docs/PLAN.md §4). A value in the
/// environment wins over one in Info.plist, so a developer can try their own registration without rebuilding.
///
/// Environment: `BETTERSHOT_GOOGLE_CLIENT_ID`, `BETTERSHOT_GOOGLE_CLIENT_SECRET`, `BETTERSHOT_ONEDRIVE_CLIENT_ID`.
/// Info.plist: `BetterShotGoogleClientID`, `BetterShotGoogleClientSecret`, `BetterShotOneDriveClientID`
/// (`scripts/bundle.sh` writes them from the same environment variables).
public enum OAuthConfigLoader {
    public static func configs(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> [CloudProvider: OAuthClientConfig] {
        var result: [CloudProvider: OAuthClientConfig] = [:]
        for provider in CloudProvider.allCases {
            let names = names(for: provider)
            guard let id = value(env: names.envID, plist: names.plistID, environment, infoDictionary) else { continue }
            let secret = names.envSecret.flatMap { value(env: $0, plist: names.plistSecret!, environment, infoDictionary) }
            result[provider] = OAuthClientConfig(clientID: id, clientSecret: secret)
        }
        return result
    }

    private static func names(for provider: CloudProvider) -> (envID: String, plistID: String, envSecret: String?, plistSecret: String?) {
        switch provider {
        case .googleDrive:
            ("BETTERSHOT_GOOGLE_CLIENT_ID", "BetterShotGoogleClientID", "BETTERSHOT_GOOGLE_CLIENT_SECRET", "BetterShotGoogleClientSecret")
        case .oneDrive:
            ("BETTERSHOT_ONEDRIVE_CLIENT_ID", "BetterShotOneDriveClientID", nil, nil)
        }
    }

    private static func value(env: String, plist: String, _ environment: [String: String], _ info: [String: Any]?) -> String? {
        for candidate in [environment[env], info?[plist] as? String] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
