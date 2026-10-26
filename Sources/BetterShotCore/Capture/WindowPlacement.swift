import CoreGraphics

/// Sizing and stacking for pinned-image windows (requirements §3.4).
public enum PinPlacement {
    /// Window size for an image of `imageSize` points: shrunk to fit `maximum`, grown so the short side is at
    /// least `minimumSide`, always keeping the aspect ratio. When both can't hold, the maximum wins.
    public static func fittedSize(for imageSize: CGSize, within maximum: CGSize, minimumSide: CGFloat = 80) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: minimumSide, height: minimumSide)
        }
        var scale: CGFloat = 1
        let shortSide = min(imageSize.width, imageSize.height)
        if shortSide < minimumSide { scale = minimumSide / shortSide }
        scale = min(scale, maximum.width / imageSize.width, maximum.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    /// Offset for the `index`-th pin so new pins don't land exactly on top of each other.
    /// AppKit's y axis points up, so "down and right" is a negative height.
    public static func cascadeOffset(forIndex index: Int) -> CGSize {
        let step: CGFloat = 28
        let slot = CGFloat(index % 8)
        return CGSize(width: step * slot, height: -step * slot)
    }
}

/// Where the floating result bar docks (requirements §3.4: "docked to an edge of the screen").
public enum DockPlacement {
    /// Bottom-left origin (AppKit) for a bar of `size` centred on `visibleFrame`'s bottom edge.
    public static func bottomCenter(size: CGSize, in visibleFrame: CGRect, margin: CGFloat = 16) -> CGPoint {
        CGPoint(
            x: max(visibleFrame.minX, visibleFrame.midX - size.width / 2),
            y: visibleFrame.minY + margin
        )
    }
}
