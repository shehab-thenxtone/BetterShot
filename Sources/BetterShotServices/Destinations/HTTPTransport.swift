import BetterShotCore
import Foundation

/// The one place network requests leave the app, so uploaders and the OAuth code can be tested with a fake.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

extension HTTPTransport {
    /// Sends `request` and returns the body of a 2xx response; anything else becomes `OAuthError.requestFailed`
    /// carrying the service's own message when it sent one.
    func sendExpectingSuccess(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw OAuthError.requestFailed(status: response.statusCode, message: Self.message(in: data))
        }
        return data
    }

    private static func message(in data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String { return message }
            if let description = object["error_description"] as? String { return description }
            if let error = object["error"] as? String { return error }
        }
        let text = String(decoding: data.prefix(200), as: UTF8.self)
        return text.isEmpty ? "no details" : text
    }
}
