import CryptoKit
import Foundation

/// The proof key for an OAuth authorization-code exchange (RFC 7636): the browser sees only the hash, so a
/// stolen code is useless without the verifier that never leaves this process.
public struct PKCE: Equatable, Sendable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    public static func generate() -> PKCE {
        PKCE(verifier: randomToken(byteCount: 32))
    }

    /// Unguessable URL-safe text; `SystemRandomNumberGenerator` is cryptographically secure on Apple platforms.
    static func randomToken(byteCount: Int) -> String {
        base64URL(Data((0..<byteCount).map { _ in UInt8.random(in: .min ... .max) }))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
