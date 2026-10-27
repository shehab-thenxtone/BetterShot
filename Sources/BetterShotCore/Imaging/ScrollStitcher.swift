/// The direction a scrolling capture moves (requirements §3.1 item 6: vertical for pages and chats,
/// horizontal for wide spreadsheets and timelines).
public enum ScrollAxis: String, CaseIterable, Sendable {
    case vertical
    case horizontal
}

/// Works out how far content moved between two captures of the same scrolling area, by comparing the pixel
/// rows (or columns) that the two frames share.
public enum ScrollStitcher {
    /// Share of the compared lines that must match. Below 1 so a fixed header or footer, a blinking cursor or a
    /// small animation can't prevent alignment.
    private static let minimumMatchShare = 0.6
    /// Blank lines match everything, so only lines with some content count as evidence.
    private static let minimumInformativeLines = 3

    /// How many lines the content moved from `previous` to `next` (the new content is the last `shift` lines of
    /// `next`). 0 means the frames are identical (the end of the content was reached). Nil when no alignment is
    /// convincing: the frames differ in size, the scroll was too large to leave enough overlap, or the content changed.
    public static func shift(from previous: PixelFrame, to next: PixelFrame, axis: ScrollAxis) -> Int? {
        guard previous.width == next.width, previous.height == next.height else { return nil }

        let before = LineSignature(previous, axis: axis)
        let after = LineSignature(next, axis: axis)
        if before.hashes == after.hashes { return 0 }

        let lineCount = before.hashes.count
        let minimumOverlap = max(4, lineCount / 20) // a handful of shared lines isn't proof
        guard lineCount > minimumOverlap else { return nil }

        var best: (shift: Int, score: Double)?
        for shift in 1...(lineCount - minimumOverlap) {
            let overlap = lineCount - shift
            var informative = 0
            var matches = 0
            for line in 0..<overlap where !after.isUniform[line] {
                informative += 1
                if after.hashes[line] == before.hashes[line + shift] { matches += 1 }
            }
            guard informative >= minimumInformativeLines else { continue }

            let score = Double(matches) / Double(informative)
            if score >= minimumMatchShare, score > (best?.score ?? 0) { best = (shift, score) }
        }
        return best?.shift
    }
}

/// A hash per row (vertical) or column (horizontal), plus whether each line is a single flat colour.
private struct LineSignature {
    let hashes: [UInt64]
    let isUniform: [Bool]

    init(_ frame: PixelFrame, axis: ScrollAxis) {
        var hashes: [UInt64] = []
        var uniform: [Bool] = []

        frame.rgba.withUnsafeBufferPointer { bytes in
            let width = frame.width
            let height = frame.height
            let lineCount = axis == .vertical ? height : width
            let lineLength = axis == .vertical ? width : height
            hashes.reserveCapacity(lineCount)
            uniform.reserveCapacity(lineCount)

            for line in 0..<lineCount {
                var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV-1a
                var isUniform = true
                var firstPixel: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)

                for position in 0..<lineLength {
                    let pixelIndex = axis == .vertical ? line * width + position : position * width + line
                    let base = pixelIndex * 4
                    let pixel = (bytes[base], bytes[base + 1], bytes[base + 2], bytes[base + 3])
                    if position == 0 { firstPixel = pixel } else if pixel != firstPixel { isUniform = false }
                    for byte in [pixel.0, pixel.1, pixel.2, pixel.3] {
                        hash ^= UInt64(byte)
                        hash = hash &* 0x0000_0100_0000_01b3
                    }
                }
                hashes.append(hash)
                uniform.append(isUniform)
            }
        }
        self.hashes = hashes
        self.isUniform = uniform
    }
}

/// Builds the long image from successive viewports. Only the newly revealed strip of each frame is kept, and the
/// pieces are joined once at the end, so memory grows with the result and not with the number of frames squared.
public struct ScrollStitchBuilder: Sendable {
    public let axis: ScrollAxis
    private let first: PixelFrame
    private var slices: [PixelFrame] = []

    /// Rows (vertical) or columns (horizontal) in the stitched image so far.
    public private(set) var length: Int

    public init(first: PixelFrame, axis: ScrollAxis) {
        self.first = first
        self.axis = axis
        length = axis == .vertical ? first.height : first.width
    }

    public var frameCount: Int { 1 + slices.count }

    /// Adds the part of `next` that is new, given that its content moved `shift` lines since the previous frame.
    /// Ignored when `shift` isn't positive, doesn't fit the frame, or `next` has a different size.
    public mutating func append(_ next: PixelFrame, shift: Int) {
        let extent = axis == .vertical ? first.height : first.width
        guard shift > 0, shift <= extent, next.width == first.width, next.height == first.height else { return }

        let strip: PixelFrame?
        switch axis {
        case .vertical:
            let start = (next.height - shift) * next.width * 4
            strip = PixelFrame(width: next.width, height: shift, rgba: Array(next.rgba[start...]))
        case .horizontal:
            var bytes: [UInt8] = []
            bytes.reserveCapacity(shift * next.height * 4)
            for row in 0..<next.height {
                let start = (row * next.width + (next.width - shift)) * 4
                bytes += next.rgba[start..<(start + shift * 4)]
            }
            strip = PixelFrame(width: shift, height: next.height, rgba: bytes)
        }
        guard let strip else { return }
        slices.append(strip)
        length += shift
    }

    /// The stitched image.
    public var result: PixelFrame {
        switch axis {
        case .vertical:
            return PixelFrame(width: first.width, height: length, rgba: first.rgba + slices.flatMap(\.rgba)) ?? first
        case .horizontal:
            var bytes: [UInt8] = []
            bytes.reserveCapacity(length * first.height * 4)
            for row in 0..<first.height {
                bytes += first.rgba[(row * first.width * 4)..<((row + 1) * first.width * 4)]
                for slice in slices {
                    bytes += slice.rgba[(row * slice.width * 4)..<((row + 1) * slice.width * 4)]
                }
            }
            return PixelFrame(width: length, height: first.height, rgba: bytes) ?? first
        }
    }
}
