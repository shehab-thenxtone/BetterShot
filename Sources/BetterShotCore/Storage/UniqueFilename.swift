import Foundation

public enum UniqueFilename {
    /// Returns `filename` if free, otherwise "name 2.ext", "name 3.ext", … — like Finder, never overwriting.
    public static func resolve(_ filename: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(filename) else { return filename }

        let url = URL(fileURLWithPath: filename)
        let fileExtension = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent

        var counter = 2
        while true {
            let candidate = fileExtension.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(fileExtension)"
            if !isTaken(candidate) { return candidate }
            counter += 1
        }
    }
}
