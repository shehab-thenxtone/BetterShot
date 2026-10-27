import BetterShotCore
import Foundation
import Network

/// A one-shot local web server for the OAuth redirect (RFC 8252 §7.3): it listens on 127.0.0.1 only, on a free
/// port, takes the browser's redirect, shows a "you can close this tab" page and hands back the request line.
public final class LoopbackReceiver: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.bettershot.oauth-loopback")
    private let lock = NSLock()
    private var listener: NWListener?
    private var buffered: String?
    private var waiter: CheckedContinuation<String, Error>?
    private var isCancelled = false

    public init() {}

    /// Starts listening and returns the redirect URI to register with the authorization request.
    public func start(redirectHost: String = "127.0.0.1") async throws -> String {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if once.claim() { continuation.resume(returning: listener.port?.rawValue ?? 0) }
                case .failed(let error):
                    if once.claim() { continuation.resume(throwing: error) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
        lock.withLock { self.listener = listener }
        return "http://\(redirectHost):\(port)"
    }

    /// The first request line that looks like an OAuth redirect (`GET /?code=…` or `GET /?error=…`), or
    /// `OAuthError.timedOut`. Cancelling the calling task stops the wait.
    public func waitForRequestLine(timeout: Duration) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await self.nextRequestLine() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw OAuthError.timedOut
            }
            defer { group.cancelAll() }
            guard let line = try await group.next() else { throw OAuthError.timedOut }
            return line
        }
    }

    public func stop() {
        let waiting = lock.withLock { () -> CheckedContinuation<String, Error>? in
            isCancelled = true
            listener?.cancel()
            listener = nil
            defer { waiter = nil }
            return waiter
        }
        waiting?.resume(throwing: CancellationError())
    }

    // MARK: Internals

    private func nextRequestLine() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let line = buffered {
                    buffered = nil
                    lock.unlock()
                    continuation.resume(returning: line)
                } else if isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiter = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            stop()
        }
    }

    private func deliver(_ line: String) {
        let waiting = lock.withLock { () -> CheckedContinuation<String, Error>? in
            guard let waiter else {
                buffered = buffered ?? line
                return nil
            }
            self.waiter = nil
            return waiter
        }
        waiting?.resume(returning: line)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            let text = String(decoding: data ?? Data(), as: UTF8.self)
            let line = text.components(separatedBy: "\r\n").first ?? ""
            let isRedirect = line.hasPrefix("GET /?") && (line.contains("code=") || line.contains("error="))
            Self.respond(on: connection, status: isRedirect ? "200 OK" : "404 Not Found", body: isRedirect ? Self.page : "")
            if isRedirect { self?.deliver(line) }
        }
    }

    private static func respond(on connection: NWConnection, status: String, body: String) {
        let payload = Data("HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)".utf8)
        connection.send(content: payload, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static let page = """
    <!doctype html><meta charset="utf-8"><title>BetterShot</title>\
    <body style="font:16px -apple-system,sans-serif;text-align:center;margin-top:20vh">\
    <h2>Done</h2><p>You can close this tab and return to BetterShot.</p></body>
    """
}

/// Lets exactly one caller through, so a continuation is resumed once even if a state handler fires repeatedly.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var isClaimed = false

    func claim() -> Bool {
        lock.withLock {
            defer { isClaimed = true }
            return !isClaimed
        }
    }
}
