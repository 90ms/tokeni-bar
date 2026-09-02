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
            Self.drawIntrinsicMutationMark(
                for: mutatedSpeciesID,
                in: context,
                width: width,
                height: height,
                opaqueBounds: opaqueBounds,
                standardOpaquePixels: standardOpaquePixels,
                palette: palette)
        }
        return context.makeImage()
    }

    /// Adds a tiny marking directly onto the original body. It uses an
    /// existing sprite-palette accent and only recolors pixels that belonged
    /// to the Standard frame, so the fallback trait can never float nearby.
    private static func drawIntrinsicMutationMark(
        for speciesID: CompanionSpeciesID,
        in context: CGContext,
        width: Int,
        height: Int,
        opaqueBounds: CGRect,
        standardOpaquePixels: [Bool],
        palette: [String])
    {
        guard standardOpaquePixels.count == width * height,
              let accent = Self.rgb(from: palette.last),
              let data = context.data
        else { return }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let normalizedTarget: (x: CGFloat, y: CGFloat) = switch speciesID {
        case .bytebot: (0.5, 0.36)
        case .cachecat: (0.68, 0.48)
        case .kernelcrab: (0.32, 0.5)
        case .loophare: (0.5, 0.3)
        case .nullslime: (0.64, 0.42)
        case .patchpanda: (0.5, 0.58)
        case .promptpup: (0.36, 0.34)
        case .queryowl: (0.5, 0.38)
        case .relayray: (0.5, 0.52)
        case .stackfox: (0.66, 0.56)
        default: (0.5, 0.5)
        }
        let targetX = opaqueBounds.minX
            + opaqueBounds.width * normalizedTarget.x
        let targetY = opaqueBounds.minY
            + opaqueBounds.height * normalizedTarget.y
        let candidates = (0..<(width * height))
            .filter { standardOpaquePixels[$0] }
            .sorted { lhs, rhs in
                let lhsX = CGFloat(lhs % width)
                let lhsY = CGFloat(lhs / width)
                let rhsX = CGFloat(rhs % width)
                let rhsY = CGFloat(rhs / width)
                return hypot(lhsX - targetX, lhsY - targetY)
                    < hypot(rhsX - targetX, rhsY - targetY)
            }
            .prefix(2)
        for index in candidates {
            let x = index % width
            let y = index / width
            let offset = y * context.bytesPerRow + x * 4
            let alpha = UInt16(bytes[offset + 3])
            bytes[offset] = UInt8(UInt16(accent.red) * alpha / 255)
            bytes[offset + 1] = UInt8(UInt16(accent.green) * alpha / 255)
            bytes[offset + 2] = UInt8(UInt16(accent.blue) * alpha / 255)
        }
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

    private static func rgb(from hex: String?) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        guard var hex else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return (
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF))
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
