import Foundation

/// The cloud file hosts that need a linked account (requirements §4.9). iCloud needs none and the chat apps are
/// handled by `MessagingHandoff`.
public enum CloudProvider: String, Codable, CaseIterable, Sendable {
    case googleDrive, oneDrive

    public var displayName: String {
        switch self {
        case .googleDrive: "Google Drive"
        case .oneDrive: "OneDrive"
        }
    }

    /// The host in the loopback redirect: Google documents 127.0.0.1, while a Microsoft app registration takes
    /// `http://localhost` (matched on any port).
    public var redirectHost: String {
        switch self {
        case .googleDrive: "127.0.0.1"
        case .oneDrive: "localhost"
        }
    }

    var authorizeURL: URL {
        switch self {
        case .googleDrive: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        case .oneDrive: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        }
    }

    var tokenURL: URL {
        switch self {
        case .googleDrive: URL(string: "https://oauth2.googleapis.com/token")!
        case .oneDrive: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        }
    }

    /// Only what uploading and sharing needs: Drive's per-file scope, OneDrive's file access plus a refresh token.
    var scopes: [String] {
        switch self {
        case .googleDrive: ["https://www.googleapis.com/auth/drive.file"]
        case .oneDrive: ["Files.ReadWrite", "offline_access"]
        }
    }

    /// Google only returns a refresh token for offline access when consent is shown.
    var extraAuthorizeParameters: [(String, String)] {
        switch self {
        case .googleDrive: [("access_type", "offline"), ("prompt", "consent")]
        case .oneDrive: []
        }
    }
}

/// The app's registration with a provider. Supplied by configuration, never hardcoded (docs/PLAN.md §4).
/// Desktop OAuth clients are public clients: a Google "secret" is not confidential, and OneDrive has none.
public struct OAuthClientConfig: Codable, Equatable, Sendable {
    public let clientID: String
    public let clientSecret: String?

    public init(clientID: String, clientSecret: String? = nil) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }
}

public enum OAuthError: Error, Equatable, Sendable {
    case notConfigured(CloudProvider)
    case notLinked(CloudProvider)
    case cancelled
    case timedOut
    case denied(String)
    case stateMismatch
    case malformedRedirect
    case badTokenResponse
    case requestFailed(status: Int, message: String)
}

extension OAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured(let provider): "\(provider.displayName) isn't set up in this build of BetterShot."
        case .notLinked(let provider): "\(provider.displayName) isn't linked. Link it in Preferences → Destinations."
        case .cancelled: "Linking was cancelled."
        case .timedOut: "Linking timed out. Try again."
        case .denied(let reason): "Access was not granted (\(reason))."
        case .stateMismatch: "The sign-in response didn't match the request. Try again."
        case .malformedRedirect: "The sign-in response couldn't be understood."
        case .badTokenResponse: "The service returned an unexpected sign-in response."
        case .requestFailed(let status, let message): "The service rejected the request (\(status)): \(message)"
        }
    }
}

/// The OAuth 2.0 authorization-code-with-PKCE requests, as pure data.
public enum OAuthRequests {
    public static func authorizeURL(
        provider: CloudProvider,
        config: OAuthClientConfig,
        redirectURI: String,
        state: String,
        codeChallenge: String
    ) -> URL {
        var components = URLComponents(url: provider.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = ([
            ("client_id", config.clientID),
            ("response_type", "code"),
            ("redirect_uri", redirectURI),
            ("scope", provider.scopes.joined(separator: " ")),
            ("state", state),
            ("code_challenge", codeChallenge),
            ("code_challenge_method", "S256"),
        ] + provider.extraAuthorizeParameters).map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.url!
    }

    public static func tokenRequest(
        provider: CloudProvider,
        config: OAuthClientConfig,
        code: String,
        codeVerifier: String,
        redirectURI: String
    ) -> URLRequest {
        form(provider.tokenURL, [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("code_verifier", codeVerifier),
            ("redirect_uri", redirectURI),
        ] + clientFields(config))
    }

    public static func refreshRequest(provider: CloudProvider, config: OAuthClientConfig, refreshToken: String) -> URLRequest {
        form(provider.tokenURL, [("grant_type", "refresh_token"), ("refresh_token", refreshToken)] + clientFields(config))
    }

    /// `application/x-www-form-urlencoded` with RFC 3986 unreserved characters left alone and everything else escaped.
    public static func formEncode(_ fields: [(String, String)]) -> String {
        fields.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&")
    }

    private static func clientFields(_ config: OAuthClientConfig) -> [(String, String)] {
        [("client_id", config.clientID)] + (config.clientSecret.map { [("client_secret", $0)] } ?? [])
    }

    private static func form(_ url: URL, _ fields: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(formEncode(fields).utf8)
        return request
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}

/// An access token and what's needed to renew it.
public struct OAuthToken: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// Reads a token endpoint's JSON. A refresh response often omits the refresh token, so the previous one is kept.
    public init(response: Data, now: Date, keeping previousRefreshToken: String? = nil) throws(OAuthError) {
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: response), !decoded.access_token.isEmpty else {
            throw .badTokenResponse
        }
        self.init(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token ?? previousRefreshToken,
            expiresAt: now.addingTimeInterval(decoded.expires_in ?? 3_600)
        )
    }

    /// True when the token is expired or about to be, so it is renewed before a request can fail halfway.
    public func isExpired(at date: Date, leeway: TimeInterval = 60) -> Bool {
        date.addingTimeInterval(leeway) >= expiresAt
    }
}

/// Reads the browser's redirect to the app's loopback address.
public enum LoopbackRedirect {
    /// `requestLine` is the first line of the HTTP request, e.g. `GET /?code=abc&state=xyz HTTP/1.1`.
    public static func authorizationCode(fromRequestLine requestLine: String, expectedState: String) throws(OAuthError) -> String {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET",
              let items = URLComponents(string: String(parts[1]))?.queryItems
        else { throw .malformedRedirect }

        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") { throw .denied(value("error_description") ?? error) }
        guard value("state") == expectedState else { throw .stateMismatch }
        guard let code = value("code"), !code.isEmpty else { throw .malformedRedirect }
        return code
    }
}
