import Foundation

/// Where finished recordings wait until the user saves or exports them. They live in Application Support, not a
/// temporary folder, so a recording isn't lost if the system clears temp files; stale ones are removed on launch.
public enum RecordingsFolder {
    public static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("BetterShot", isDirectory: true).appendingPathComponent("Recordings", isDirectory: true)
    }

    /// A fresh, unique `.mp4` path inside `directory` (the folder itself is created when recording starts).
    public static func url(forNewRecordingIn directory: URL = defaultDirectory) -> URL {
        directory.appendingPathComponent("Recording-\(UUID().uuidString).mp4")
    }

    /// Deletes files in `directory` last modified more than `age` seconds before `now`. A missing folder is fine.
    public static func removeFiles(in directory: URL, olderThan age: TimeInterval, now: Date = Date()) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = now.addingTimeInterval(-age)
        for file in files {
            guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modified < cutoff else { continue }
            try? fileManager.removeItem(at: file)
        }
    }
}
