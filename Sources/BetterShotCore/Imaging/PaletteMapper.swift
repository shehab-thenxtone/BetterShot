/// Recolours RGBA pixels with a fixed palette, optionally with Floyd–Steinberg error diffusion so gradients
/// don't band at low colour counts (the GIF "dithering" option, requirements §3.1a).
public struct PaletteMapper: Sendable {
    public let palette: [RGB]
    /// Nearest palette index for every 5-bit-per-channel colour cell: one table lookup per pixel instead of a
    /// search over the whole palette, which matters for long recordings.
    private let lookup: [UInt8]

    /// An empty palette falls back to black; more than 256 colours are cut to 256 (GIF's limit).
    public init(palette: [RGB]) {
        let resolved = palette.isEmpty ? [RGB(r: 0, g: 0, b: 0)] : Array(palette.prefix(256))
        var table = [UInt8](repeating: 0, count: 32 * 32 * 32)
        for r in 0..<32 {
            for g in 0..<32 {
                for b in 0..<32 {
                    let (cr, cg, cb) = (r * 8 + 4, g * 8 + 4, b * 8 + 4) // centre of the cell
                    var bestIndex = 0
                    var bestDistance = Int.max
                    for (index, color) in resolved.enumerated() {
                        let (dr, dg, db) = (Int(color.r) - cr, Int(color.g) - cg, Int(color.b) - cb)
                        let distance = dr * dr + dg * dg + db * db
                        if distance < bestDistance {
                            bestDistance = distance
                            bestIndex = index
                        }
                    }
                    table[(r << 10) | (g << 5) | b] = UInt8(bestIndex)
                }
            }
        }
        self.palette = resolved
        lookup = table
    }

    /// RGBA in, RGBA out containing only palette colours; alpha is passed through. `width` is in pixels.
    public func map(rgba pixels: [UInt8], width: Int, dithering: Bool) -> [UInt8] {
        guard width > 0, pixels.count >= width * 4 else { return pixels }
        return dithering ? mapDithered(pixels, width: width) : mapNearest(pixels)
    }

    // MARK: Private

    private func cell(_ r: Int, _ g: Int, _ b: Int) -> Int {
        ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
    }

    private func mapNearest(_ pixels: [UInt8]) -> [UInt8] {
        var output = pixels
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            let color = palette[Int(lookup[cell(Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2]))])]
            output[index] = color.r
            output[index + 1] = color.g
            output[index + 2] = color.b
        }
        return output
    }

    /// Floyd–Steinberg: each pixel's rounding error is pushed to its right and lower neighbours (7, 3, 5, 1 sixteenths).
    private func mapDithered(_ pixels: [UInt8], width: Int) -> [UInt8] {
        let height = pixels.count / (width * 4)
        var output = pixels
        let rowSize = (width + 2) * 3 // one pixel of padding on each side
        var current = [Int](repeating: 0, count: rowSize)
        var next = [Int](repeating: 0, count: rowSize)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = min(max(Int(pixels[index]) + current[(x + 1) * 3] / 16, 0), 255)
                let g = min(max(Int(pixels[index + 1]) + current[(x + 1) * 3 + 1] / 16, 0), 255)
                let b = min(max(Int(pixels[index + 2]) + current[(x + 1) * 3 + 2] / 16, 0), 255)

                let color = palette[Int(lookup[cell(r, g, b)])]
                output[index] = color.r
                output[index + 1] = color.g
                output[index + 2] = color.b

                let errors = (r - Int(color.r), g - Int(color.g), b - Int(color.b))
                for (channel, error) in [errors.0, errors.1, errors.2].enumerated() {
                    current[(x + 2) * 3 + channel] += error * 7
                    next[x * 3 + channel] += error * 3
                    next[(x + 1) * 3 + channel] += error * 5
                    next[(x + 2) * 3 + channel] += error
                }
            }
            swap(&current, &next)
            for slot in next.indices { next[slot] = 0 }
        }
        return output
    }
}
