import Foundation

/// A dotted release number such as `1.4.2`, comparable the way people read versions (`1.10` is newer than `1.9`).
public struct AppVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let components: [Int]

    /// Accepts `1.2.3`, `v1.2`, and tags with a suffix (`1.2.3-beta.1`, `1.2.3+45`), which is ignored.
    public init?(_ text: String) {
        var core = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if core.first == "v" || core.first == "V" { core.removeFirst() }
        if let end = core.firstIndex(where: { $0 == "-" || $0 == "+" }) { core = String(core[..<end]) }

        let parsed = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parsed.isEmpty, parsed.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        components = parsed.compactMap { $0 }
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    /// Missing trailing parts count as zero, so `1.2` equals `1.2.0`.
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let length = max(lhs.components.count, rhs.components.count)
        for index in 0..<length {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

public struct AvailableUpdate: Equatable, Sendable {
    public let version: AppVersion
    public let pageURL: URL

    public init(version: AppVersion, pageURL: URL) {
        self.version = version
        self.pageURL = pageURL
    }
}

/// Reads a GitHub "latest release" document: `{"tag_name": "v1.2.0", "html_url": "https://…", "draft": false, "prerelease": false}`.
public enum UpdateFeed {
    /// The release it describes, or nil for an unreadable document, a draft or a prerelease, or a non-https page.
    public static func release(from data: Data) -> AvailableUpdate? {
        struct Release: Decodable {
            let tag_name: String
            let html_url: String
            let draft: Bool?
            let prerelease: Bool?
        }
        guard
            let release = try? JSONDecoder().decode(Release.self, from: data),
            release.draft != true, release.prerelease != true,
            let version = AppVersion(release.tag_name),
            let url = URL(string: release.html_url), url.scheme == "https"
        else { return nil }
        return AvailableUpdate(version: version, pageURL: url)
    }
}
