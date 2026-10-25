import Foundation

/// Remembers the folder "Save" writes to, so saving never needs a dialog (requirements §3.2, §4.9).
/// It only changes when the user explicitly picks a new one (Save As… or Preferences).
public protocol SaveFolderStoring: Sendable {
    /// The last folder the user picked, or the system Screenshots location on first use.
    var folder: URL { get }
    func setFolder(_ url: URL)
}

public enum SaveError: Error, Equatable, LocalizedError, Sendable {
    case encodingFailed
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: "The image couldn't be encoded as PNG."
        case .writeFailed(let reason): "The image couldn't be saved: \(reason)"
        }
    }
}
