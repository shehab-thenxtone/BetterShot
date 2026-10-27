import BetterShotCore
import Foundation

/// Where an upload ended up. `isShareableLink` is false when the host couldn't create a public link and
/// `location` is only something the owner can open (or a local path).
public struct UploadResult: Equatable, Sendable {
    public let location: URL
    public let isShareableLink: Bool

    public init(location: URL, isShareableLink: Bool) {
        self.location = location
        self.isShareableLink = isShareableLink
    }
}

public protocol CloudUploading: Sendable {
    func upload(_ data: Data, filename: String, mimeType: String) async throws -> UploadResult
}

/// File hosts reject or mangle path characters, so names that came from a user template are made safe first.
func cloudSafeFilename(_ name: String) -> String {
    name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
}

// MARK: Google Drive

/// Uploads to the root of the user's Drive with the per-file scope, then makes the file readable by anyone with
/// the link. REST: https://developers.google.com/drive/api/guides/manage-uploads#multipart
public struct GoogleDriveUploader: CloudUploading {
    private let authorizer: OAuthAuthorizer
    private let transport: any HTTPTransport

    public init(authorizer: OAuthAuthorizer, transport: any HTTPTransport = URLSessionTransport()) {
        self.authorizer = authorizer
        self.transport = transport
    }

    public func upload(_ data: Data, filename: String, mimeType: String) async throws -> UploadResult {
        let token = try await authorizer.accessToken(for: .googleDrive)

        let boundary = "bettershot-\(UUID().uuidString)"
        let metadata = try JSONSerialization.data(withJSONObject: ["name": cloudSafeFilename(filename)])
        var body = Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8)
        body.append(metadata)
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--".utf8))

        var request = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let file = try Self.decodeFile(try await transport.sendExpectingSuccess(request))

        var share = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(file.id)/permissions")!)
        share.httpMethod = "POST"
        share.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        share.setValue("application/json", forHTTPHeaderField: "Content-Type")
        share.httpBody = try JSONSerialization.data(withJSONObject: ["role": "reader", "type": "anyone"])
        let isShared = (try? await transport.sendExpectingSuccess(share)) != nil

        return UploadResult(location: file.link, isShareableLink: isShared)
    }

    private static func decodeFile(_ data: Data) throws -> (id: String, link: URL) {
        struct File: Decodable { let id: String; let webViewLink: String }
        guard let file = try? JSONDecoder().decode(File.self, from: data), let link = URL(string: file.webViewLink) else {
            throw OAuthError.badTokenResponse
        }
        return (file.id, link)
    }
}

// MARK: OneDrive

/// Uploads into a "BetterShot" folder at the root of the user's OneDrive, then asks for an anonymous view link.
/// Work and school accounts can forbid anonymous links; then the file's own web URL is returned instead.
public struct OneDriveUploader: CloudUploading {
    private let authorizer: OAuthAuthorizer
    private let transport: any HTTPTransport

    public init(authorizer: OAuthAuthorizer, transport: any HTTPTransport = URLSessionTransport()) {
        self.authorizer = authorizer
        self.transport = transport
    }

    public func upload(_ data: Data, filename: String, mimeType: String) async throws -> UploadResult {
        let token = try await authorizer.accessToken(for: .oneDrive)
        let encodedName = cloudSafeFilename(filename).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "image.png"

        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/drive/root:/BetterShot/\(encodedName):/content")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let item = try Self.decodeItem(try await transport.sendExpectingSuccess(request))

        var share = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(item.id)/createLink")!)
        share.httpMethod = "POST"
        share.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        share.setValue("application/json", forHTTPHeaderField: "Content-Type")
        share.httpBody = try JSONSerialization.data(withJSONObject: ["type": "view", "scope": "anonymous"])

        if let response = try? await transport.sendExpectingSuccess(share), let link = Self.decodeLink(response) {
            return UploadResult(location: link, isShareableLink: true)
        }
        return UploadResult(location: item.webURL, isShareableLink: false)
    }

    private static func decodeItem(_ data: Data) throws -> (id: String, webURL: URL) {
        struct Item: Decodable { let id: String; let webUrl: String }
        guard let item = try? JSONDecoder().decode(Item.self, from: data), let url = URL(string: item.webUrl) else {
            throw OAuthError.badTokenResponse
        }
        return (item.id, url)
    }

    private static func decodeLink(_ data: Data) -> URL? {
        struct Link: Decodable { struct Inner: Decodable { let webUrl: String }; let link: Inner }
        return (try? JSONDecoder().decode(Link.self, from: data)).flatMap { URL(string: $0.link.webUrl) }
    }
}

// MARK: iCloud Drive

public enum ICloudDriveError: LocalizedError, Equatable {
    case unavailable
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: "iCloud Drive isn't available. Turn it on in System Settings → Apple Account → iCloud."
        case .writeFailed(let reason): "The file couldn't be written to iCloud Drive (\(reason))."
        }
    }
}

/// Copies into a "BetterShot" folder of the user's iCloud Drive, which the system then syncs. This needs no
/// entitlement because the app isn't sandboxed. A public share link can't be created this way (that needs the
/// iCloud entitlement), so the result is the file's location unless the system happens to offer a link.
public struct ICloudDriveUploader: CloudUploading {
    public static let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

    private let root: URL

    public init(root: URL = ICloudDriveUploader.defaultRoot) {
        self.root = root
    }

    public var isAvailable: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    public func upload(_ data: Data, filename: String, mimeType: String) async throws -> UploadResult {
        guard isAvailable else { throw ICloudDriveError.unavailable }
        let folder = root.appendingPathComponent("BetterShot", isDirectory: true)
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = UniqueFilename.resolve(
                cloudSafeFilename(filename),
                isTaken: { fileManager.fileExists(atPath: folder.appendingPathComponent($0).path) }
            )
            let file = folder.appendingPathComponent(name)
            try data.write(to: file, options: .withoutOverwriting)
            let link = try? fileManager.url(forPublishingUbiquitousItemAt: file, expiration: nil)
            return UploadResult(location: link ?? file, isShareableLink: link != nil)
        } catch {
            throw ICloudDriveError.writeFailed(error.localizedDescription)
        }
    }
}
