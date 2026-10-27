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
    private let service: String

    public init(service: String = "com.bettershot.app.oauth") {
        self.service = service
    }

    public func token(for provider: CloudProvider) -> OAuthToken? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(OAuthToken.self, from: data)
    }

    public func save(_ token: OAuthToken, for provider: CloudProvider) throws {
        let data = try JSONEncoder().encode(token)
        removeToken(for: provider)
        var attributes = baseQuery(provider)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func removeToken(for provider: CloudProvider) {
        SecItemDelete(baseQuery(provider) as CFDictionary)
    }

    private func baseQuery(_ provider: CloudProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
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
