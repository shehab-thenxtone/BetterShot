import BetterShotCore
import Foundation
import Security

/// Where linked-account tokens live. Tokens are credentials, so the real store is the Keychain, never UserDefaults.
public protocol TokenStoring: Sendable {
    func token(for provider: CloudProvider) -> OAuthToken?
    func save(_ token: OAuthToken, for provider: CloudProvider) throws
    func removeToken(for provider: CloudProvider)
}

public struct KeychainError: LocalizedError, Equatable {
    public let status: OSStatus

    public var errorDescription: String? {
        let text = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
        return "The account couldn't be saved to the Keychain (\(text))."
    }
}

public struct KeychainTokenStore: TokenStoring {
    private let blob: KeychainBlob

    public init(service: String = "com.bettershot.app.oauth") {
        blob = KeychainBlob(service: service)
    }

    public func token(for provider: CloudProvider) -> OAuthToken? {
        blob.read(account: provider.rawValue).flatMap { try? JSONDecoder().decode(OAuthToken.self, from: $0) }
    }

    public func save(_ token: OAuthToken, for provider: CloudProvider) throws {
        try blob.write(try JSONEncoder().encode(token), account: provider.rawValue)
    }

    public func removeToken(for provider: CloudProvider) {
        blob.remove(account: provider.rawValue)
    }
}

/// Tokens held in memory only: for tests, and the fallback if a build has no Keychain access.
public final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [CloudProvider: OAuthToken] = [:]

    public init() {}

    public func token(for provider: CloudProvider) -> OAuthToken? { lock.withLock { tokens[provider] } }
    public func save(_ token: OAuthToken, for provider: CloudProvider) throws { lock.withLock { tokens[provider] = token } }
    public func removeToken(for provider: CloudProvider) { lock.withLock { tokens[provider] = nil } }
}
