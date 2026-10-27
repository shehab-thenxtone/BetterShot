import Foundation
import Testing
@testable import BetterShotCore

struct OAuthRequestsTests {
    private let config = OAuthClientConfig(clientID: "client id", clientSecret: "s&cret")

    private func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private func fields(_ request: URLRequest) -> [String: String] {
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        return Dictionary(uniqueKeysWithValues: body.split(separator: "&").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return (parts[0], parts[1].removingPercentEncoding ?? parts[1])
        })
    }

    @Test func authorizeURLCarriesPKCEAndState() {
        let url = OAuthRequests.authorizeURL(
            provider: .googleDrive, config: config, redirectURI: "http://127.0.0.1:5555", state: "xyz", codeChallenge: "chal"
        )
        let items = query(url)

        #expect(url.host == "accounts.google.com")
        #expect(items["client_id"] == "client id")
        #expect(items["response_type"] == "code")
        #expect(items["redirect_uri"] == "http://127.0.0.1:5555")
        #expect(items["state"] == "xyz")
        #expect(items["code_challenge"] == "chal")
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["scope"] == "https://www.googleapis.com/auth/drive.file")
        #expect(items["access_type"] == "offline") // without it Google issues no refresh token
    }

    @Test func oneDriveAsksForARefreshToken() {
        let url = OAuthRequests.authorizeURL(provider: .oneDrive, config: config, redirectURI: "r", state: "s", codeChallenge: "c")

        #expect(query(url)["scope"] == "Files.ReadWrite offline_access")
        #expect(url.host == "login.microsoftonline.com")
    }

    @Test func tokenRequestSendsTheVerifierAndEscapesValues() {
        let request = OAuthRequests.tokenRequest(
            provider: .googleDrive, config: config, code: "a+b/c", codeVerifier: "ver", redirectURI: "http://127.0.0.1:1"
        )
        let body = fields(request)

        #expect(request.httpMethod == "POST")
        #expect(request.url?.host == "oauth2.googleapis.com")
        #expect(body["grant_type"] == "authorization_code")
        #expect(body["code"] == "a+b/c")
        #expect(body["code_verifier"] == "ver")
        #expect(body["client_secret"] == "s&cret")
        #expect(String(decoding: request.httpBody ?? Data(), as: UTF8.self).contains("s%26cret"))
    }

    @Test func aPublicClientSendsNoSecret() {
        let request = OAuthRequests.refreshRequest(provider: .oneDrive, config: .init(clientID: "id"), refreshToken: "r")

        #expect(fields(request)["client_secret"] == nil)
        #expect(fields(request)["grant_type"] == "refresh_token")
        #expect(fields(request)["refresh_token"] == "r")
    }
}

struct OAuthTokenTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    @Test func readsATokenResponse() throws {
        let json = Data(#"{"access_token":"at","refresh_token":"rt","expires_in":3600}"#.utf8)

        let token = try OAuthToken(response: json, now: now)

        #expect(token == OAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: now.addingTimeInterval(3_600)))
    }

    @Test func aRefreshResponseKeepsTheOldRefreshToken() throws {
        let json = Data(#"{"access_token":"new","expires_in":60}"#.utf8)

        let token = try OAuthToken(response: json, now: now, keeping: "old")

        #expect(token.refreshToken == "old")
    }

    @Test func rejectsAResponseWithoutAnAccessToken() {
        #expect(throws: OAuthError.badTokenResponse) { try OAuthToken(response: Data(#"{"error":"x"}"#.utf8), now: now) }
        #expect(throws: OAuthError.badTokenResponse) { try OAuthToken(response: Data("nope".utf8), now: now) }
    }

    @Test func expiresEarlyByTheLeeway() {
        let token = OAuthToken(accessToken: "a", refreshToken: nil, expiresAt: now.addingTimeInterval(100))

        #expect(!token.isExpired(at: now, leeway: 60))
        #expect(token.isExpired(at: now.addingTimeInterval(41), leeway: 60))
        #expect(token.isExpired(at: now.addingTimeInterval(200)))
    }
}

struct LoopbackRedirectTests {
    @Test func extractsTheCode() throws {
        let code = try LoopbackRedirect.authorizationCode(fromRequestLine: "GET /?code=abc&state=xyz HTTP/1.1", expectedState: "xyz")

        #expect(code == "abc")
    }

    @Test func rejectsAMismatchedState() {
        #expect(throws: OAuthError.stateMismatch) {
            try LoopbackRedirect.authorizationCode(fromRequestLine: "GET /?code=abc&state=evil HTTP/1.1", expectedState: "xyz")
        }
    }

    @Test func reportsAProviderError() {
        #expect(throws: OAuthError.denied("The user denied access")) {
            try LoopbackRedirect.authorizationCode(
                fromRequestLine: "GET /?error=access_denied&error_description=The%20user%20denied%20access&state=xyz HTTP/1.1",
                expectedState: "xyz"
            )
        }
    }

    @Test func rejectsRequestsThatAreNotARedirect() {
        for line in ["", "POST /?code=a&state=xyz HTTP/1.1", "GET /favicon.ico HTTP/1.1", "GET /?state=xyz HTTP/1.1"] {
            #expect(throws: OAuthError.self) { try LoopbackRedirect.authorizationCode(fromRequestLine: line, expectedState: "xyz") }
        }
    }
}

struct CloudProviderTests {
    @Test func eachProviderUsesTheRedirectHostItsRegistrationAccepts() {
        #expect(CloudProvider.googleDrive.redirectHost == "127.0.0.1")
        #expect(CloudProvider.oneDrive.redirectHost == "localhost")
    }

    @Test func aClientConfigSurvivesBeingStoredAsJSON() throws {
        let config = OAuthClientConfig(clientID: "id", clientSecret: "secret")

        let decoded = try JSONDecoder().decode(OAuthClientConfig.self, from: JSONEncoder().encode(config))

        #expect(decoded == config)
        #expect(try JSONDecoder().decode(OAuthClientConfig.self, from: Data(#"{"clientID":"x"}"#.utf8)).clientSecret == nil)
    }
}

struct MessagingHandoffTests {
    @Test func opensTheInstalledDesktopApp() {
        let plan = MessagingHandoff.plan(for: .whatsApp, isInstalled: { $0 == "net.whatsapp.WhatsApp" })

        #expect(plan == .openApp(bundleIdentifier: "net.whatsapp.WhatsApp"))
    }

    @Test func fallsBackToTheWebClientWhenNotInstalled() {
        #expect(MessagingHandoff.plan(for: .whatsApp, isInstalled: { _ in false }) == .openWeb(URL(string: "https://web.whatsapp.com")!))
        #expect(MessagingHandoff.plan(for: .telegram, isInstalled: { _ in false }) == .openWeb(URL(string: "https://web.telegram.org/a/")!))
    }

    @Test func recognisesEitherTelegramClient() {
        let plan = MessagingHandoff.plan(for: .telegram, isInstalled: { $0 == "org.telegram.desktop" })

        #expect(plan == .openApp(bundleIdentifier: "org.telegram.desktop"))
    }

    @Test func storageTargetsMapToTheirKind() {
        #expect(StorageTarget.telegram.messagingApp == .telegram)
        #expect(StorageTarget.oneDrive.cloudProvider == .oneDrive)
        #expect(StorageTarget.iCloud.cloudProvider == nil)
        #expect(StorageTarget.local.messagingApp == nil)
    }
}
