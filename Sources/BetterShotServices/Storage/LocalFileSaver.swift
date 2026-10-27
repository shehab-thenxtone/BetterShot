import BetterShotCore
import Foundation

/// Silent "Save" for files that already exist on disk (MP4 and GIF recordings): copies into the remembered
/// folder under the recording name pattern, never overwriting.
public struct LocalFileSaver: Sendable {
    private let folderStore: any SaveFolderStoring
    private let template: FilenameTemplate
    private let timeZone: TimeZone

    public init(
        folderStore: any SaveFolderStoring,
        template: FilenameTemplate = .recording,
        timeZone: TimeZone = .current
    ) {
        self.folderStore = folderStore
        self.template = template
        self.timeZone = timeZone
    }

    @discardableResult
    public func copy(_ source: URL, fileExtension: String, at date: Date = Date()) throws(SaveError) -> URL {
        let folder = folderStore.folder
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = UniqueFilename.resolve(
                template.filename(for: date, fileExtension: fileExtension, timeZone: timeZone),
                isTaken: { fileManager.fileExists(atPath: folder.appendingPathComponent($0).path) }
            )
            let destination = folder.appendingPathComponent(name)
            try fileManager.copyItem(at: source, to: destination)
            return destination
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }
}
