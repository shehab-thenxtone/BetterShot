/// An opaque 8-bit colour.
public struct RGB: Equatable, Hashable, Sendable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Picks a small palette that represents an image well (median cut), for GIF's limited colour depth.
public enum PaletteQuantizer {
    private enum Channel { case r, g, b }

    /// At most `maxColors` colours from RGBA `pixels` (alpha is ignored). Fewer come back when the image
    /// has fewer distinct colours. Empty input or `maxColors <= 0` gives an empty palette.
    public static func palette(from pixels: [UInt8], maxColors: Int) -> [RGB] {
        guard maxColors > 0, pixels.count >= 4 else { return [] }

        var colors: [RGB] = []
        colors.reserveCapacity(pixels.count / 4)
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            colors.append(RGB(r: pixels[index], g: pixels[index + 1], b: pixels[index + 2]))
        }

        // Each box is a contiguous range of `colors`; repeatedly split the most spread-out one at its median.
        var boxes: [Range<Int>] = [0..<colors.count]
        while boxes.count < maxColors {
            var best: (index: Int, channel: Channel, score: Double)?
            for (index, box) in boxes.enumerated() where box.count > 1 {
                let (channel, range) = widestChannel(in: colors[box])
                guard range > 0 else { continue }
                let score = Double(range) * Double(box.count).squareRoot()
                if best == nil || score > best?.score ?? 0 { best = (index, channel, score) }
            }
            guard let split = best else { break } // every box is a single colour

            let box = boxes[split.index]
            colors[box].sort { value($0, split.channel) < value($1, split.channel) }
            let middle = box.lowerBound + box.count / 2
            boxes[split.index] = box.lowerBound..<middle
            boxes.append(middle..<box.upperBound)
        }

        var seen = Set<RGB>()
        return boxes.map { average(of: colors[$0]) }.filter { seen.insert($0).inserted }
    }

    // MARK: Private

    private static func value(_ color: RGB, _ channel: Channel) -> UInt8 {
        switch channel {
        case .r: color.r
        case .g: color.g
        case .b: color.b
        }
    }

    private static func widestChannel(in colors: ArraySlice<RGB>) -> (Channel, Int) {
        var low = (r: UInt8.max, g: UInt8.max, b: UInt8.max)
        var high = (r: UInt8.min, g: UInt8.min, b: UInt8.min)
        for color in colors {
            low = (min(low.r, color.r), min(low.g, color.g), min(low.b, color.b))
            high = (max(high.r, color.r), max(high.g, color.g), max(high.b, color.b))
        }
        let ranges: [(Channel, Int)] = [(.r, Int(high.r) - Int(low.r)), (.g, Int(high.g) - Int(low.g)), (.b, Int(high.b) - Int(low.b))]
        return ranges.max { $0.1 < $1.1 } ?? (.r, 0)
    }

    private static func average(of colors: ArraySlice<RGB>) -> RGB {
        var sum = (r: 0, g: 0, b: 0)
        for color in colors {
            sum.r += Int(color.r)
            sum.g += Int(color.g)
            sum.b += Int(color.b)
        }
        let count = max(colors.count, 1)
        let half = count / 2 // rounds to nearest instead of truncating
        return RGB(r: UInt8((sum.r + half) / count), g: UInt8((sum.g + half) / count), b: UInt8((sum.b + half) / count))
    }
}
