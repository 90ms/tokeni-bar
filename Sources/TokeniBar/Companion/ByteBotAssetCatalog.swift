import AppKit
import Dispatch
import Foundation
import TokeniCore

@MainActor
final class CompanionAssetCatalog {
    static let shared = CompanionAssetCatalog()

    private let manifests: [CompanionSpeciesID: CompanionSpriteManifest]
    private let assetDirectories: [CompanionSpeciesID: URL]
    private let sheetCache = NSCache<NSString, ImageBox>()
    private let frameCache = NSCache<NSString, ImageBox>()
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        var loadedManifests: [CompanionSpeciesID: CompanionSpriteManifest] = [:]
        var loadedDirectories: [CompanionSpeciesID: URL] = [:]
        for speciesID in CompanionSpeciesID.allCases {
            guard let assetDirectory = Self.assetDirectory(for: speciesID),
                  let manifest = Self.loadManifest(from: assetDirectory)
            else { continue }

            loadedManifests[speciesID] = manifest
            loadedDirectories[speciesID] = assetDirectory
        }
        self.manifests = loadedManifests
        self.assetDirectories = loadedDirectories
        self.sheetCache.totalCostLimit = 8 * 1_024 * 1_024
        self.sheetCache.countLimit = 12
        self.frameCache.totalCostLimit = 12 * 1_024 * 1_024
        self.frameCache.countLimit = 768
        let pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main)
        pressureSource.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.removeCachedImages()
            }
        }
        pressureSource.resume()
        self.memoryPressureSource = pressureSource
    }

    func removeCachedImages() {
        self.frameCache.removeAllObjects()
        self.sheetCache.removeAllObjects()
    }

    func animation(
        for speciesID: CompanionSpeciesID?,
        behavior: CompanionBehavior) -> CompanionSpriteManifest.Animation?
    {
        self.manifest(for: speciesID)?.animation(for: behavior)
    }

    func frame(
        speciesID requestedSpeciesID: CompanionSpeciesID?,
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        variantID: CompanionVariantID,
        behavior: CompanionBehavior,
        index: Int) -> CGImage?
    {
        let speciesID = stage == .egg
            ? CompanionSpeciesID.bytebot
            : requestedSpeciesID ?? .bytebot
        guard let manifest = self.manifests[speciesID],
              let sheetName = manifest.sheetName(
                  for: stage,
                  variantID: variantID,
                  fallbackRarity: rarity),
              let animation = manifest.animation(for: behavior)
        else {
            return nil
        }

        let column = min(max(index, 0), max(animation.frameCount - 1, 0))
        let frameKey = NSString(string: [
            speciesID.rawValue,
            sheetName,
            variantID.rawValue,
            behavior.rawValue,
            String(column),
        ].joined(separator: ":"))
        if let cached = self.frameCache.object(forKey: frameKey) {
            return cached.image
        }
        guard let sheet = self.sheet(
            speciesID: speciesID,
            fileName: sheetName)
        else { return nil }

        let frameWidth = sheet.width / manifest.columns
        let frameHeight = sheet.height / manifest.rows
        guard frameWidth > 0, frameHeight > 0 else { return nil }
        let x = column * frameWidth
        let y = animation.row * frameHeight
        guard x >= 0,
              y >= 0,
              x + frameWidth <= sheet.width,
              y + frameHeight <= sheet.height
        else {
            return nil
        }
        guard let cropped = sheet.cropping(to: CGRect(
            x: x,
            y: y,
            width: frameWidth,
            height: frameHeight)),
            let frame = Self.detachedCopy(
                of: cropped,
                width: frameWidth,
                height: frameHeight,
                palette: manifest.palette,
                mutatedSpeciesID: variantID == .mutated && stage != .egg
                    ? speciesID
                    : nil)
        else { return nil }
        self.frameCache.setObject(
            ImageBox(frame),
            forKey: frameKey,
            cost: frameWidth * frameHeight * 4)
        return frame
    }

    private func sheet(
        speciesID: CompanionSpeciesID,
        fileName: String) -> CGImage?
    {
        let key = NSString(string: "\(speciesID.rawValue):\(fileName)")
        if let cached = self.sheetCache.object(forKey: key) {
            return cached.image
        }
        guard let directory = self.assetDirectories[speciesID],
              let image = NSImage(contentsOf: directory.appending(path: fileName)),
              let sheet = image.cgImage(
                  forProposedRect: nil,
                  context: nil,
                  hints: nil)
        else { return nil }
        self.sheetCache.setObject(
            ImageBox(sheet),
            forKey: key,
            cost: sheet.bytesPerRow * sheet.height)
        return sheet
    }

    private static func detachedCopy(
        of image: CGImage,
        width: Int,
        height: Int,
        palette: [String],
        mutatedSpeciesID: CompanionSpeciesID?) -> CGImage?
    {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height))
        let standardOpaquePixels = Self.opaquePixelMask(
            in: context,
            width: width,
            height: height)
        if let mutatedSpeciesID,
           let opaqueBounds = Self.opaqueBounds(
               in: context,
               width: width,
               height: height)
        {
            Self.drawMutationFeature(
                for: mutatedSpeciesID,
                in: context,
                canvasSize: CGSize(width: CGFloat(width), height: CGFloat(height)),
                opaqueBounds: opaqueBounds,
                palette: palette)
            Self.removeDetachedMutationPixels(
                from: context,
                width: width,
                height: height,
                standardOpaquePixels: standardOpaquePixels)
        }
        return context.makeImage()
    }

    private static func opaquePixelMask(
        in context: CGContext,
        width: Int,
        height: Int) -> [Bool]
    {
        guard let data = context.data else { return [] }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        return (0..<(width * height)).map { index in
            let x = index % width
            let y = index / width
            return bytes[y * context.bytesPerRow + x * 4 + 3] > 0
        }
    }

    /// A mutation may extend the original silhouette, but every new group of
    /// pixels must touch the pet. Original action particles remain untouched.
    private static func removeDetachedMutationPixels(
        from context: CGContext,
        width: Int,
        height: Int,
        standardOpaquePixels: [Bool])
    {
        guard standardOpaquePixels.count == width * height,
              let data = context.data
        else { return }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let mutatedOpaquePixels = Self.opaquePixelMask(
            in: context,
            width: width,
            height: height)
        var visited = Array(repeating: false, count: width * height)

        for start in 0..<(width * height)
        where mutatedOpaquePixels[start]
            && !standardOpaquePixels[start]
            && !visited[start]
        {
            var stack = [start]
            var component: [Int] = []
            var touchesStandard = false
            visited[start] = true
            while let index = stack.popLast() {
                component.append(index)
                let x = index % width
                let y = index / width
                let neighbors = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < width ? index + 1 : -1,
                    y > 0 ? index - width : -1,
                    y + 1 < height ? index + width : -1,
                ]
                for neighbor in neighbors where neighbor >= 0 {
                    if standardOpaquePixels[neighbor] {
                        touchesStandard = true
                    } else if mutatedOpaquePixels[neighbor], !visited[neighbor] {
                        visited[neighbor] = true
                        stack.append(neighbor)
                    }
                }
            }
            guard !touchesStandard else { continue }
            for index in component {
                let x = index % width
                let y = index / width
                let offset = y * context.bytesPerRow + x * 4
                bytes[offset] = 0
                bytes[offset + 1] = 0
                bytes[offset + 2] = 0
                bytes[offset + 3] = 0
            }
        }
    }

    /// Finds the pet body in the detached RGBA frame. The largest connected
    /// component deliberately excludes detached celebration sparks and action
    /// particles so the intrinsic body trait remains attached to the pet.
    private static func opaqueBounds(
        in context: CGContext,
        width: Int,
        height: Int) -> CGRect?
    {
        guard let data = context.data else { return nil }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let pixelCount = width * height
        var opaque = Array(repeating: false, count: pixelCount)
        for y in 0..<height {
            let row = y * context.bytesPerRow
            for x in 0..<width {
                opaque[y * width + x] = bytes[row + x * 4 + 3] > 0
            }
        }

        var visited = Array(repeating: false, count: pixelCount)
        var bestCount = 0
        var bestBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
        for start in 0..<pixelCount where opaque[start] && !visited[start] {
            var stack = [start]
            visited[start] = true
            var componentCount = 0
            var minX = width
            var minY = height
            var maxX = -1
            var maxY = -1
            while let index = stack.popLast() {
                let x = index % width
                let y = index / width
                componentCount += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                let neighbors = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < width ? index + 1 : -1,
                    y > 0 ? index - width : -1,
                    y + 1 < height ? index + width : -1,
                ]
                for neighbor in neighbors
                where neighbor >= 0 && opaque[neighbor] && !visited[neighbor]
                {
                    visited[neighbor] = true
                    stack.append(neighbor)
                }
            }
            if componentCount > bestCount {
                bestCount = componentCount
                bestBounds = (minX, minY, maxX, maxY)
            }
        }
        guard let bestBounds else { return nil }
        return CGRect(
            x: CGFloat(bestBounds.minX),
            y: CGFloat(bestBounds.minY),
            width: CGFloat(max(bestBounds.maxX - bestBounds.minX + 1, 1)),
            height: CGFloat(max(bestBounds.maxY - bestBounds.minY + 1, 1)))
    }

    /// Derives the intrinsic Mutation resource from the Standard frame. Keep
    /// these traits small and use the sprite's body colors: a Mutation should
    /// read as a close biological variation, not as an attached decoration.
    private static func drawMutationFeature(
        for speciesID: CompanionSpeciesID,
        in context: CGContext,
        canvasSize: CGSize,
        opaqueBounds: CGRect,
        palette: [String])
    {
        let pixel = max(floor(min(canvasSize.width, canvasSize.height) / 32), 1)
        let outline = Self.color(from: palette.first)
            ?? CGColor(red: 0.03, green: 0.08, blue: 0.15, alpha: 1)
        let body = Self.color(from: palette.dropFirst().first)
            ?? CGColor(red: 0.12, green: 0.35, blue: 0.48, alpha: 1)

        func snapped(_ value: CGFloat) -> CGFloat {
            floor(value / pixel) * pixel
        }
        func block(
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat)
        {
            let requested = CGRect(
                x: snapped(x),
                y: snapped(y),
                width: min(max(snapped(width), pixel), canvasSize.width),
                height: min(max(snapped(height), pixel), canvasSize.height))
            let canvas = CGRect(origin: .zero, size: canvasSize)
            let frame = CGRect(
                x: min(max(requested.minX, canvas.minX), canvas.maxX - requested.width),
                y: min(max(requested.minY, canvas.minY), canvas.maxY - requested.height),
                width: requested.width,
                height: requested.height)
            context.setFillColor(outline)
            context.fill(frame)
            let inset = frame.insetBy(dx: pixel, dy: pixel)
            if inset.width > 0, inset.height > 0 {
                context.setFillColor(body)
                context.fill(inset)
            }
        }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)

        let left = opaqueBounds.minX
        let right = opaqueBounds.maxX
        let bottom = opaqueBounds.minY
        let top = opaqueBounds.maxY
        let centerX = opaqueBounds.midX
        let centerY = opaqueBounds.midY

        switch speciesID {
        case .bytebot:
            // A short fork at the tip of the existing antenna.
            block(x: centerX, y: top - pixel, width: pixel, height: pixel * 4)
            block(x: centerX - pixel * 2, y: top + pixel * 2, width: pixel * 2, height: pixel)
            block(x: centerX + pixel, y: top + pixel * 2, width: pixel * 2, height: pixel)
        case .cachecat:
            // A compact split at the existing tail side.
            block(x: right - pixel, y: centerY, width: pixel * 4, height: pixel)
            block(x: right + pixel * 2, y: centerY - pixel * 2, width: pixel, height: pixel * 2)
            block(x: right + pixel * 2, y: centerY + pixel, width: pixel, height: pixel * 2)
        case .kernelcrab:
            // One claw is only slightly broader than its counterpart.
            block(x: left - pixel * 3, y: centerY - pixel * 2, width: pixel * 4, height: pixel * 4)
            block(x: left - pixel * 4, y: centerY + pixel, width: pixel * 2, height: pixel * 2)
        case .loophare:
            // A small central ear loop echoes the original paired ears.
            block(x: centerX - pixel, y: top - pixel, width: pixel * 3, height: pixel * 5)
            context.clear(CGRect(x: snapped(centerX), y: snapped(top + pixel), width: pixel, height: pixel * 2))
        case .nullslime:
            // A small bud grows directly from the slime body.
            block(x: right - pixel, y: top - pixel, width: pixel * 3, height: pixel)
            block(x: right + pixel, y: top, width: pixel * 3, height: pixel * 3)
        case .patchpanda:
            // Tiny stepped tufts alter the round ears without covering them.
            block(x: left, y: top, width: pixel * 2, height: pixel * 2)
            block(x: right - pixel, y: top, width: pixel * 2, height: pixel * 2)
            block(x: left - pixel, y: top + pixel, width: pixel, height: pixel)
            block(x: right + pixel, y: top + pixel, width: pixel, height: pixel)
        case .promptpup:
            // One ear has a short folded tip.
            block(x: left - pixel * 2, y: top - pixel, width: pixel * 4, height: pixel * 2)
            block(x: left - pixel * 3, y: top - pixel * 2, width: pixel * 2, height: pixel * 2)
        case .queryowl:
            // Subtle paired brow tufts follow the existing head contour.
            block(x: left + pixel, y: top, width: pixel * 2, height: pixel * 2)
            block(x: right - pixel * 2, y: top, width: pixel * 2, height: pixel * 2)
        case .relayray:
            // Small paired points extend the original fins.
            block(x: left - pixel * 2, y: centerY, width: pixel * 3, height: pixel * 2)
            block(x: right - pixel, y: centerY, width: pixel * 3, height: pixel * 2)
        case .stackfox:
            // A compact branch at the tail base suggests a second tail.
            block(x: right - pixel, y: bottom + pixel * 2, width: pixel * 3, height: pixel * 2)
            block(x: right + pixel, y: bottom + pixel * 3, width: pixel * 3, height: pixel * 3)
        }
    }

    private static func color(from hex: String?) -> CGColor? {
        guard var hex else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return CGColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1)
    }

    private func manifest(
        for speciesID: CompanionSpeciesID?) -> CompanionSpriteManifest?
    {
        self.manifests[speciesID ?? .bytebot]
    }

    private static func assetDirectory(for speciesID: CompanionSpeciesID) -> URL? {
        let relativeComponents = ["CompanionAssets", speciesID.rawValue]
        if let root = Bundle.main.resourceURL {
            let candidate = relativeComponents.reduce(root) {
                $0.appending(path: $1, directoryHint: .isDirectory)
            }
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // SwiftPM's generated Bundle.module accessor terminates the process when
        // its resource bundle is absent. Packaged apps must fail soft and show the
        // fallback icon; development builds can use SwiftPM's resource bundle.
        guard Bundle.main.bundleURL.pathExtension.lowercased() != "app",
              let root = Bundle.module.resourceURL
        else { return nil }
        let candidate = relativeComponents.reduce(root) {
            $0.appending(path: $1, directoryHint: .isDirectory)
        }
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    private static func loadManifest(from directory: URL) -> CompanionSpriteManifest? {
        let url = directory.appending(path: "manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(
                  CompanionSpriteManifest.self,
                  from: data),
              manifest.schemaVersion == 2,
              manifest.logicalFrameSize > 0,
              manifest.columns > 0,
              manifest.rows > 0
        else {
            return nil
        }
        return manifest
    }
}

private final class ImageBox {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}
