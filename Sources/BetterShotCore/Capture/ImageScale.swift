import CoreGraphics

public enum ImageScale {
    /// Pixels per point implied by an image file's DPI metadata, or nil when the file records none.
    /// macOS Retina screenshots carry 144 DPI, which is 2 pixels per point. Clamped to 1...4 so odd
    /// metadata (e.g. a 300 DPI scan) can't make the editor canvas absurdly small.
    public static func pointScale(forDPI dpi: Double?) -> CGFloat? {
        guard let dpi, dpi > 0 else { return nil }
        return CGFloat(min(max(dpi / 72, 1), 4))
    }
}
