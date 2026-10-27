import Foundation

/// User-configurable filename pattern. Supports `{date}` (yyyy-MM-dd) and `{time}` (HH.mm.ss).
public struct FilenameTemplate: Equatable, Hashable, Codable, Sendable {
    public static let `default` = FilenameTemplate(rawValue: "Screenshot {date} at {time}")
    /// Fixed name pattern for saved screen recordings (MP4 / GIF).
    public static let recording = FilenameTemplate(rawValue: "Screen Recording {date} at {time}")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public func filename(for date: Date, fileExtension: String, timeZone: TimeZone = .current) -> String {
        let pattern = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.default.rawValue
            : rawValue

        let name = pattern
            .replacingOccurrences(of: "{date}", with: Self.format(date, "yyyy-MM-dd", timeZone))
            .replacingOccurrences(of: "{time}", with: Self.format(date, "HH.mm.ss", timeZone))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")

        return "\(name).\(fileExtension)"
    }

    private static func format(_ date: Date, _ pattern: String, _ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
