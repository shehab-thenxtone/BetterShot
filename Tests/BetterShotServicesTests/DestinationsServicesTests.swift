import BetterShotCore
import Foundation
import Testing
@testable import BetterShotServices

/// Answers requests from a closure and remembers them, standing in for the network.
private final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let handler: @Sendable (URLRequest) -> (Int, String)

    init(_ handler: @escaping @Sendable (URLRequest) -> (Int, String)) {
        self.handler = handler
    }

    var requests: [URLRequest] { lock.withLock { recorded } }

    func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        lock.withLock { recorded.append(request) }
        let (status, body) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

private func bodyFields(_ request: URLRequest) -> [String: String] {
    let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
    return Dictionary(uniqueKeysWithValues: body.split(separator: "&").map { pair in
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        return (parts[0], parts[1].removingPercentEncoding ?? parts[1])
    })
}

struct PKCETests {
    @Test func matchesTheRFC7636Example() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatedVerifiersAreLongUniqueAndURLSafe() {
        let first = PKCE.generate()
        let second = PKCE.generate()

        #expect(first.verifier != second.verifier)
        #expect(first.verifier.count >= 43) // RFC 7636 minimum
        #expect(first.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}

struct OAuthAuthorizerTests {
    private let config = OAuthClientConfig(clientID: "cid")
    private let start = Date(timeIntervalSince1970: 10_000)

    private func authorizer(
        store: InMemoryTokenStore = InMemoryTokenStore(),
        now: Date? = nil,
        transport: FakeTransport
    ) -> OAuthAuthorizer {
        let date = now ?? start
        return OAuthAuthorizer(configs: [.googleDrive: config], store: store, transport: transport, now: { date })
    }

    @Test func linkingRunsTheWholeBrowserFlowAndStoresTheToken() async throws {
        let store = InMemoryTokenStore()
        let transport = FakeTransport { _ in (200, #"{"access_token":"at","refresh_token":"rt","expires_in":3600}"#) }
        let authorizer = authorizer(store: store, transport: transport)

        // The "browser": reads the authorization URL, then follows the redirect back to the loopback address.
        try await authorizer.link(.googleDrive, openBrowser: { url in
            let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            let redirect = URL(string: "\(query["redirect_uri"]!)/?code=the-code&state=\(query["state"]!)")!
            _ = try? await URLSession.shared.data(from: redirect)
        })

        #expect(store.token(for: .googleDrive) == OAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: start.addingTimeInterval(3_600)))
        let exchange = try #require(transport.requests.first)
        #expect(bodyFields(exchange)["code"] == "the-code")
        #expect(bodyFields(exchange)["code_verifier"]?.isEmpty == false)
        #expect(bodyFields(exchange)["redirect_uri"]?.hasPrefix("http://127.0.0.1:") == true)
    }

    @Test func aRedirectWithTheWrongStateIsRejectedAndNothingIsStored() async throws {
        let store = InMemoryTokenStore()
        let transport = FakeTransport { _ in (200, "{}") }
        let authorizer = authorizer(store: store, transport: transport)

        await #expect(throws: OAuthError.stateMismatch) {
            try await authorizer.link(.googleDrive, openBrowser: { url in
                let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                _ = try? await URLSession.shared.data(from: URL(string: "\(query["redirect_uri"]!)/?code=x&state=forged")!)
            })
        }
        #expect(store.token(for: .googleDrive) == nil)
        #expect(transport.requests.isEmpty) // the code is never exchanged
    }

    @Test func linkingTimesOutWhenTheUserNeverReturns() async {
        let authorizer = authorizer(transport: FakeTransport { _ in (200, "{}") })

        await #expect(throws: OAuthError.timedOut) {
            try await authorizer.link(.googleDrive, timeout: .milliseconds(150), openBrowser: { _ in })
        }
    }

    @Test func linkingFailsWithoutAClientID() async {
        let authorizer = OAuthAuthorizer(configs: [:], store: InMemoryTokenStore(), transport: FakeTransport { _ in (200, "{}") })

        await #expect(throws: OAuthError.notConfigured(.oneDrive)) { try await authorizer.link(.oneDrive, openBrowser: { _ in }) }
        #expect(!authorizer.isConfigured(.oneDrive))
    }

    @Test func aFreshTokenIsReturnedWithoutANetworkCall() async throws {
        let store = InMemoryTokenStore()
        try store.save(OAuthToken(accessToken: "fresh", refreshToken: "rt", expiresAt: start.addingTimeInterval(3_600)), for: .googleDrive)
        let transport = FakeTransport { _ in (500, "") }

        let token = try await authorizer(store: store, transport: transport).accessToken(for: .googleDrive)

        #expect(token == "fresh")
        #expect(transport.requests.isEmpty)
    }

    @Test func anExpiredTokenIsRefreshedAndTheRefreshTokenKept() async throws {
        let store = InMemoryTokenStore()
        try store.save(OAuthToken(accessToken: "old", refreshToken: "rt", expiresAt: start.addingTimeInterval(-5)), for: .googleDrive)
        let transport = FakeTransport { _ in (200, #"{"access_token":"new","expires_in":3600}"#) }

        let token = try await authorizer(store: store, transport: transport).accessToken(for: .googleDrive)

        #expect(token == "new")
        #expect(bodyFields(try #require(transport.requests.first))["grant_type"] == "refresh_token")
        #expect(store.token(for: .googleDrive)?.refreshToken == "rt")
    }

    @Test func aRevokedGrantUnlinksTheAccount() async throws {
        let store = InMemoryTokenStore()
        try store.save(OAuthToken(accessToken: "old", refreshToken: "rt", expiresAt: start.addingTimeInterval(-5)), for: .googleDrive)
        let transport = FakeTransport { _ in (400, #"{"error":"invalid_grant"}"#) }

        await #expect(throws: OAuthError.notLinked(.googleDrive)) {
            try await authorizer(store: store, transport: transport).accessToken(for: .googleDrive)
        }
        #expect(store.token(for: .googleDrive) == nil)
    }

    @Test func anUnlinkedAccountHasNoToken() async {
        await #expect(throws: OAuthError.notLinked(.googleDrive)) {
            try await authorizer(transport: FakeTransport { _ in (200, "") }).accessToken(for: .googleDrive)
        }
    }
}

struct ClientConfigTests {
    @Test func aClientIDEnteredLaterTakesEffectImmediately() throws {
        let configs = InMemoryClientConfigStore()
        let authorizer = OAuthAuthorizer(configLookup: { configs.config(for: $0) }, store: InMemoryTokenStore())

        #expect(!authorizer.isConfigured(.googleDrive))
        try configs.save(OAuthClientConfig(clientID: "mine", clientSecret: "secret"), for: .googleDrive)

        #expect(authorizer.isConfigured(.googleDrive))
        #expect(!authorizer.isConfigured(.oneDrive))
    }

    @Test func theUsersOwnClientIsUsedForSigningIn() async throws {
        let configs = InMemoryClientConfigStore()
        try configs.save(OAuthClientConfig(clientID: "my-own-client"), for: .oneDrive)
        let transport = FakeTransport { _ in (200, #"{"access_token":"at","refresh_token":"rt","expires_in":3600}"#) }
        let store = InMemoryTokenStore()
        let authorizer = OAuthAuthorizer(configLookup: { configs.config(for: $0) }, store: store, transport: transport)

        let seen = SeenURL()
        try await authorizer.link(.oneDrive, openBrowser: { url in
            seen.set(url)
            let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            _ = try? await URLSession.shared.data(from: URL(string: "\(query["redirect_uri"]!)/?code=c&state=\(query["state"]!)")!)
        })

        let query = URLComponents(url: try #require(seen.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.first { $0.name == "client_id" }?.value == "my-own-client")
        // Microsoft registrations take http://localhost, so that is the redirect host used, and the flow still completes.
        #expect(query.first { $0.name == "redirect_uri" }?.value?.hasPrefix("http://localhost:") == true)
        #expect(store.token(for: .oneDrive)?.accessToken == "at")
    }

    @Test func theKeychainStoresKeepAndForgetConfigsAndTokens() throws {
        let service = "com.bettershot.tests.\(UUID().uuidString)"
        let configs = KeychainClientConfigStore(service: service)
        let tokens = KeychainTokenStore(service: service + ".tokens")
        defer {
            configs.removeConfig(for: .googleDrive)
            tokens.removeToken(for: .googleDrive)
        }

        try configs.save(OAuthClientConfig(clientID: "id", clientSecret: "s"), for: .googleDrive)
        try tokens.save(OAuthToken(accessToken: "a", refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 5_000)), for: .googleDrive)

        #expect(configs.config(for: .googleDrive) == OAuthClientConfig(clientID: "id", clientSecret: "s"))
        #expect(configs.config(for: .oneDrive) == nil)
        #expect(tokens.token(for: .googleDrive)?.refreshToken == "r")

        try configs.save(OAuthClientConfig(clientID: "id2"), for: .googleDrive) // replaces rather than duplicating
        #expect(configs.config(for: .googleDrive) == OAuthClientConfig(clientID: "id2"))

        configs.removeConfig(for: .googleDrive)
        tokens.removeToken(for: .googleDrive)
        #expect(configs.config(for: .googleDrive) == nil)
        #expect(tokens.token(for: .googleDrive) == nil)
    }
}

/// Carries the URL the fake browser was asked to open out of the (Sendable) closure.
private final class SeenURL: @unchecked Sendable {
    private let lock = NSLock()
    private var value: URL?
    var url: URL? { lock.withLock { value } }
    func set(_ url: URL) { lock.withLock { value = url } }
}

struct CloudUploaderTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47])

    private func linked(_ provider: CloudProvider, transport: FakeTransport) throws -> OAuthAuthorizer {
        let store = InMemoryTokenStore()
        try store.save(OAuthToken(accessToken: "tok", refreshToken: nil, expiresAt: .distantFuture), for: provider)
        return OAuthAuthorizer(configs: [provider: OAuthClientConfig(clientID: "c")], store: store, transport: transport)
    }

    @Test func googleDriveUploadsThenSharesAndReturnsTheViewLink() async throws {
        let transport = FakeTransport { request in
            request.url?.path.hasSuffix("/permissions") == true
                ? (200, #"{"id":"p"}"#)
                : (200, #"{"id":"file1","webViewLink":"https://drive.google.com/file/d/file1/view"}"#)
        }
        let uploader = GoogleDriveUploader(authorizer: try linked(.googleDrive, transport: transport), transport: transport)

        let result = try await uploader.upload(png, filename: "Shot: 1/2.png", mimeType: "image/png")

        #expect(result == UploadResult(location: URL(string: "https://drive.google.com/file/d/file1/view")!, isShareableLink: true))
        let upload = try #require(transport.requests.first)
        #expect(upload.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(upload.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/related; boundary=") == true)
        let body = String(decoding: upload.httpBody ?? Data(), as: UTF8.self)
        #expect(body.contains(#""name":"Shot- 1-2.png""#)) // path characters made safe
        #expect(body.contains("Content-Type: image/png"))
        let share = try #require(transport.requests.last)
        #expect(share.url?.path == "/drive/v3/files/file1/permissions")
        #expect(String(decoding: share.httpBody ?? Data(), as: UTF8.self).contains("anyone"))
    }

    @Test func googleDriveStillReturnsTheFileWhenSharingIsRefused() async throws {
        let transport = FakeTransport { request in
            request.url?.path.hasSuffix("/permissions") == true
                ? (403, #"{"error":{"message":"nope"}}"#)
                : (200, #"{"id":"f","webViewLink":"https://drive.google.com/file/d/f/view"}"#)
        }
        let uploader = GoogleDriveUploader(authorizer: try linked(.googleDrive, transport: transport), transport: transport)

        let result = try await uploader.upload(png, filename: "a.png", mimeType: "image/png")

        #expect(!result.isShareableLink)
    }

    @Test func aRejectedUploadReportsTheServiceMessage() async throws {
        let transport = FakeTransport { _ in (403, #"{"error":{"message":"Storage quota exceeded"}}"#) }
        let uploader = GoogleDriveUploader(authorizer: try linked(.googleDrive, transport: transport), transport: transport)

        await #expect(throws: OAuthError.requestFailed(status: 403, message: "Storage quota exceeded")) {
            try await uploader.upload(png, filename: "a.png", mimeType: "image/png")
        }
    }

    @Test func oneDriveUploadsToTheAppFolderThenCreatesAnAnonymousLink() async throws {
        let transport = FakeTransport { request in
            request.url?.path.hasSuffix("/createLink") == true
                ? (201, #"{"link":{"webUrl":"https://1drv.ms/i/abc"}}"#)
                : (201, #"{"id":"item9","webUrl":"https://onedrive.live.com/item9"}"#)
        }
        let uploader = OneDriveUploader(authorizer: try linked(.oneDrive, transport: transport), transport: transport)

        let result = try await uploader.upload(png, filename: "My Shot.png", mimeType: "image/png")

        #expect(result == UploadResult(location: URL(string: "https://1drv.ms/i/abc")!, isShareableLink: true))
        let put = try #require(transport.requests.first)
        #expect(put.httpMethod == "PUT")
        #expect(put.url?.absoluteString == "https://graph.microsoft.com/v1.0/me/drive/root:/BetterShot/My%20Shot.png:/content")
        #expect(put.httpBody == png)
        #expect(String(decoding: try #require(transport.requests.last?.httpBody), as: UTF8.self).contains("anonymous"))
    }

    @Test func oneDriveFallsBackToTheItemPageWhenAnonymousLinksAreBlocked() async throws {
        let transport = FakeTransport { request in
            request.url?.path.hasSuffix("/createLink") == true
                ? (403, #"{"error":{"message":"blocked"}}"#)
                : (201, #"{"id":"i","webUrl":"https://onedrive.live.com/i"}"#)
        }
        let uploader = OneDriveUploader(authorizer: try linked(.oneDrive, transport: transport), transport: transport)

        let result = try await uploader.upload(png, filename: "a.png", mimeType: "image/png")

        #expect(result == UploadResult(location: URL(string: "https://onedrive.live.com/i")!, isShareableLink: false))
    }

    @Test func iCloudCopiesIntoABetterShotFolderWithoutOverwriting() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let uploader = ICloudDriveUploader(root: root)

        let first = try await uploader.upload(png, filename: "a.png", mimeType: "image/png")
        let second = try await uploader.upload(png, filename: "a.png", mimeType: "image/png")

        #expect(first.location.deletingLastPathComponent().lastPathComponent == "BetterShot")
        #expect(first.location != second.location)
        #expect(try Data(contentsOf: first.location) == png)
    }

    @Test func iCloudReportsWhenDriveIsOff() async {
        let uploader = ICloudDriveUploader(root: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))

        #expect(!uploader.isAvailable)
        await #expect(throws: ICloudDriveError.unavailable) { try await uploader.upload(Data(), filename: "a.png", mimeType: "image/png") }
    }
}

struct OAuthConfigLoaderTests {
    @Test func readsClientIDsFromTheEnvironment() {
        let configs = OAuthConfigLoader.configs(
            environment: ["BETTERSHOT_GOOGLE_CLIENT_ID": "g-id", "BETTERSHOT_GOOGLE_CLIENT_SECRET": "g-secret", "BETTERSHOT_ONEDRIVE_CLIENT_ID": "o-id"],
            infoDictionary: nil
        )

        #expect(configs[.googleDrive] == OAuthClientConfig(clientID: "g-id", clientSecret: "g-secret"))
        #expect(configs[.oneDrive] == OAuthClientConfig(clientID: "o-id"))
    }

    @Test func fallsBackToInfoPlistAndPrefersTheEnvironment() {
        let info: [String: Any] = ["BetterShotGoogleClientID": "plist-id", "BetterShotOneDriveClientID": "plist-o"]

        let configs = OAuthConfigLoader.configs(environment: ["BETTERSHOT_GOOGLE_CLIENT_ID": "env-id"], infoDictionary: info)

        #expect(configs[.googleDrive]?.clientID == "env-id")
        #expect(configs[.oneDrive]?.clientID == "plist-o")
    }

    @Test func blankValuesCountAsNotConfigured() {
        let configs = OAuthConfigLoader.configs(environment: ["BETTERSHOT_GOOGLE_CLIENT_ID": "  "], infoDictionary: ["BetterShotOneDriveClientID": ""])

        #expect(configs.isEmpty)
    }
}
