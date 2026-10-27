import BetterShotCore
import Foundation

/// Links accounts and keeps their access tokens fresh. The browser steps are injected (`openBrowser`), so the
/// whole flow runs in tests against a fake transport.
public actor OAuthAuthorizer {
    private let configLookup: @Sendable (CloudProvider) -> OAuthClientConfig?
    private let store: any TokenStoring
    private let transport: any HTTPTransport
    private let now: @Sendable () -> Date
    private let makeReceiver: @Sendable () -> LoopbackReceiver

    /// `configLookup` is asked every time, so a client ID the user enters in Preferences takes effect at once.
    public init(
        configLookup: @escaping @Sendable (CloudProvider) -> OAuthClientConfig?,
        store: any TokenStoring,
        transport: any HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeReceiver: @escaping @Sendable () -> LoopbackReceiver = { LoopbackReceiver() }
    ) {
        self.configLookup = configLookup
        self.store = store
        self.transport = transport
        self.now = now
        self.makeReceiver = makeReceiver
    }

    /// A fixed set of client IDs.
    public init(
        configs: [CloudProvider: OAuthClientConfig],
        store: any TokenStoring,
        transport: any HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeReceiver: @escaping @Sendable () -> LoopbackReceiver = { LoopbackReceiver() }
    ) {
        self.init(configLookup: { configs[$0] }, store: store, transport: transport, now: now, makeReceiver: makeReceiver)
    }

    /// False when there is no client ID for the provider (neither bundled nor entered by the user), so linking can't work.
    public nonisolated func isConfigured(_ provider: CloudProvider) -> Bool { configLookup(provider) != nil }

    public nonisolated func isLinked(_ provider: CloudProvider) -> Bool { store.token(for: provider) != nil }

    public func unlink(_ provider: CloudProvider) {
        store.removeToken(for: provider)
    }

    /// Signs in through the user's browser and stores the resulting token. Cancelling the calling task abandons it.
    public func link(_ provider: CloudProvider, timeout: Duration = .seconds(180), openBrowser: @Sendable (URL) async -> Void) async throws {
        guard let config = configLookup(provider) else { throw OAuthError.notConfigured(provider) }

        let receiver = makeReceiver()
        defer { receiver.stop() }
        let redirectURI = try await receiver.start(redirectHost: provider.redirectHost)
        let pkce = PKCE.generate()
        let state = PKCE.randomToken(byteCount: 16)

        await openBrowser(OAuthRequests.authorizeURL(
            provider: provider, config: config, redirectURI: redirectURI, state: state, codeChallenge: pkce.challenge
        ))
        let line = try await receiver.waitForRequestLine(timeout: timeout)
        let code = try LoopbackRedirect.authorizationCode(fromRequestLine: line, expectedState: state)

        let response = try await transport.sendExpectingSuccess(OAuthRequests.tokenRequest(
            provider: provider, config: config, code: code, codeVerifier: pkce.verifier, redirectURI: redirectURI
        ))
        try store.save(try OAuthToken(response: response, now: now()), for: provider)
    }

    /// A token good for at least the next minute, renewed first if needed.
    public func accessToken(for provider: CloudProvider) async throws -> String {
        guard let config = configLookup(provider) else { throw OAuthError.notConfigured(provider) }
        guard let token = store.token(for: provider) else { throw OAuthError.notLinked(provider) }
        guard token.isExpired(at: now()) else { return token.accessToken }
        guard let refreshToken = token.refreshToken else {
            store.removeToken(for: provider)
            throw OAuthError.notLinked(provider)
        }

        do {
            let response = try await transport.sendExpectingSuccess(
                OAuthRequests.refreshRequest(provider: provider, config: config, refreshToken: refreshToken)
            )
            let renewed = try OAuthToken(response: response, now: now(), keeping: refreshToken)
            try store.save(renewed, for: provider)
            return renewed.accessToken
        } catch OAuthError.requestFailed(let status, _) where status == 400 || status == 401 {
            // The grant was revoked or expired: the account must be linked again.
            store.removeToken(for: provider)
            throw OAuthError.notLinked(provider)
        }
    }
}
