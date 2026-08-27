import AppKit
import SwiftUI

/// Rasterizes SF Symbols once before they enter a repeating companion
/// animation. Passing `Image(systemName:)` through a SwiftUI timeline causes
/// CoreUI to accumulate vector-glyph layers on some macOS versions.
@MainActor
enum CompanionRasterSymbolCache {
    private static var images: [String: NSImage] = [:]
    private static let rasterDimension = 64

    static func image(named name: String) -> NSImage? {
        if let image = self.images[name] {
            return image
        }
        guard let symbol = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil)?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)),
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: self.rasterDimension,
                  pixelsHigh: self.rasterDimension,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0)
        else { return nil }

        bitmap.size = NSSize(
            width: self.rasterDimension,
            height: self.rasterDimension)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        symbol.draw(
            in: NSRect(
                x: 8,
                y: 8,
                width: self.rasterDimension - 16,
                height: self.rasterDimension - 16),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil)
        NSGraphicsContext.current?.flushGraphics()

        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        image.isTemplate = true
        self.images[name] = image
        return image
    }
}

struct CompanionRasterSymbol: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if let image = CompanionRasterSymbolCache.image(named: self.name) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: self.size, height: self.size)
        }
    }
}
