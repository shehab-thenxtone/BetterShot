import BetterShotCore
import Foundation

/// The OAuth client the user registered themselves (their own Google Cloud or Microsoft Entra app), entered in
/// Preferences → Destinations. It lets a build with no bundled client ID still sign in. A Google client secret
/// travels with it, so it lives in the Keychain, not in UserDefaults.
public protocol ClientConfigStoring: Sendable {
    func config(for provider: CloudProvider) -> OAuthClientConfig?
    func save(_ config: OAuthClientConfig, for provider: CloudProvider) throws
    func removeConfig(for provider: CloudProvider)
}

public struct KeychainClientConfigStore: ClientConfigStoring {
    private let blob: KeychainBlob

    public init(service: String = "com.bettershot.app.oauth-client") {
        blob = KeychainBlob(service: service)
    }

    public func config(for provider: CloudProvider) -> OAuthClientConfig? {
        blob.read(account: provider.rawValue).flatMap { try? JSONDecoder().decode(OAuthClientConfig.self, from: $0) }
    }

    public func save(_ config: OAuthClientConfig, for provider: CloudProvider) throws {
        try blob.write(try JSONEncoder().encode(config), account: provider.rawValue)
    }

    public func removeConfig(for provider: CloudProvider) {
        blob.remove(account: provider.rawValue)
    }
}

/// Configs held in memory only, for tests.
public final class InMemoryClientConfigStore: ClientConfigStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var configs: [CloudProvider: OAuthClientConfig] = [:]

    public init() {}

    public func config(for provider: CloudProvider) -> OAuthClientConfig? { lock.withLock { configs[provider] } }
    public func save(_ config: OAuthClientConfig, for provider: CloudProvider) throws { lock.withLock { configs[provider] = config } }
    public func removeConfig(for provider: CloudProvider) { lock.withLock { configs[provider] = nil } }
}
