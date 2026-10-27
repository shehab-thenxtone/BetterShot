import BetterShotCore
import Foundation
import Testing
@testable import BetterShotServices

private struct StubTransport: HTTPTransport {
    let status: Int
    let body: String

    func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

struct UpdateCheckerTests {
    private let feed = URL(string: "https://api.example.com/releases/latest")!
    private let release = #"{"tag_name":"v1.2.0","html_url":"https://example.com/r/1.2.0"}"#

    private func checker(current: String, status: Int = 200, body: String? = nil) -> UpdateChecker {
        UpdateChecker(feedURL: feed, currentVersion: AppVersion(current)!, transport: StubTransport(status: status, body: body ?? release))
    }

    @Test func reportsANewerRelease() async throws {
        let result = try await checker(current: "1.1.9").check()

        #expect(result == .available(AvailableUpdate(version: AppVersion("1.2.0")!, pageURL: URL(string: "https://example.com/r/1.2.0")!)))
    }

    @Test func reportsUpToDateForTheSameOrANewerBuild() async throws {
        #expect(try await checker(current: "1.2.0").check() == .upToDate(current: AppVersion("1.2.0")!))
        #expect(try await checker(current: "2.0.0").check() == .upToDate(current: AppVersion("2.0.0")!))
    }

    @Test func anUnreadableFeedIsAnError() async {
        await #expect(throws: UpdateCheckError.unreadableFeed) { try await checker(current: "1.0", body: "<html>").check() }
    }

    @Test func aFailingServiceIsAnError() async {
        await #expect(throws: OAuthError.self) { try await checker(current: "1.0", status: 404, body: "{}").check() }
    }

    @Test func theFeedURLComesFromTheEnvironmentOrInfoPlistAndMustBeHTTPS() {
        let info: [String: Any] = ["BetterShotUpdateFeedURL": "https://plist.example.com/feed"]

        #expect(UpdateChecker.feedURL(environment: ["BETTERSHOT_UPDATE_FEED_URL": "https://env.example.com/feed"], infoDictionary: info)?.host == "env.example.com")
        #expect(UpdateChecker.feedURL(environment: [:], infoDictionary: info)?.host == "plist.example.com")
        #expect(UpdateChecker.feedURL(environment: ["BETTERSHOT_UPDATE_FEED_URL": "http://insecure.example.com"], infoDictionary: nil) == nil)
        #expect(UpdateChecker.feedURL(environment: [:], infoDictionary: nil) == nil)
    }

    @Test func theCurrentVersionComesFromTheBundle() {
        #expect(UpdateChecker.currentVersion(infoDictionary: ["CFBundleShortVersionString": "0.1.0"]) == AppVersion("0.1.0"))
        #expect(UpdateChecker.currentVersion(infoDictionary: nil) == nil)
    }
}
