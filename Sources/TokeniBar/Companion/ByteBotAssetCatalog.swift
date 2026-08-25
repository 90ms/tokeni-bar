import AppKit
import Foundation
import TokeniCore

@MainActor
final class CompanionAssetCatalog {
    static let shared = CompanionAssetCatalog()

    private let manifests: [CompanionSpeciesID: CompanionSpriteManifest]
    private let assetDirectories: [CompanionSpeciesID: URL]
    private let sheetCache = NSCache<NSString, ImageBox>()
    private let frameCache = NSCache<NSString, ImageBox>()

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
        if let mutatedSpeciesID,
           let opaqueBounds = Self.opaqueBounds(
               in: context,
               width: width,
               height: height)
        {
            Self.drawMutationFeature(
                for: mutatedSpeciesID,
                in: context,
                opaqueBounds: opaqueBounds)
        }
        return context.makeImage()
    }

    /// Finds the visible sprite in the detached RGBA frame. Mutation details
    /// are anchored to this box so they follow differently sized life stages
    /// and animated poses instead of floating at fixed sheet coordinates.
    private static func opaqueBounds(
        in context: CGContext,
        width: Int,
        height: Int) -> CGRect?
    {
        guard let data = context.data else { return nil }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            let row = y * context.bytesPerRow
            for x in 0..<width where bytes[row + x * 4 + 3] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(max(maxX - minX + 1, 1)),
            height: CGFloat(max(maxY - minY + 1, 1)))
    }

    /// Adds a stable, species-specific silhouette detail without recoloring the
    /// original sprite. Coordinates are expressed in the manifest's logical
    /// 32-pixel frame and scale for future higher-resolution sheets.
    private static func drawMutationFeature(
        for speciesID: CompanionSpeciesID,
        in context: CGContext,
        opaqueBounds: CGRect)
    {
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
            context.fill(CGRect(x: x, y: y, width: width, height: height))
        }
        func line(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            context.beginPath()
            context.move(to: first)
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }

        let scaleX = opaqueBounds.width / 32
        let scaleY = opaqueBounds.height / 32
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: opaqueBounds.minX, y: opaqueBounds.minY)
        context.scaleBy(x: scaleX, y: scaleY)
        context.setShouldAntialias(false)
        context.setLineWidth(1 / max(min(scaleX, scaleY), 0.25))
        context.setLineCap(.square)
        context.setStrokeColor(CGColor(red: 0.03, green: 0.11, blue: 0.21, alpha: 1))
        context.setFillColor(CGColor(red: 0.03, green: 0.11, blue: 0.21, alpha: 1))

        switch speciesID {
        case .bytebot:
            // Forked antenna.
            line([CGPoint(x: 16, y: 24), CGPoint(x: 16, y: 29), CGPoint(x: 13, y: 31)])
            line([CGPoint(x: 16, y: 29), CGPoint(x: 19, y: 31)])
            rect(12, 30, 2, 2)
            rect(18, 30, 2, 2)
        case .cachecat:
            // Split tail tips.
            line([CGPoint(x: 23, y: 12), CGPoint(x: 28, y: 15), CGPoint(x: 31, y: 19)])
            line([CGPoint(x: 28, y: 15), CGPoint(x: 31, y: 13)])
        case .kernelcrab:
            // Oversized asymmetric claw.
            rect(1, 14, 5, 5)
            rect(0, 16, 2, 5)
            rect(5, 17, 2, 4)
        case .loophare:
            // Loop bridge between the ears.
            line([
                CGPoint(x: 11, y: 27), CGPoint(x: 11, y: 31),
                CGPoint(x: 21, y: 31), CGPoint(x: 21, y: 27),
            ])
        case .nullslime:
            // A small satellite blob.
            rect(25, 23, 4, 4)
            rect(27, 27, 2, 2)
        case .patchpanda:
            // Notched ear tufts.
            rect(5, 25, 3, 3)
            rect(24, 25, 3, 3)
            rect(7, 28, 2, 3)
            rect(23, 28, 2, 3)
        case .promptpup:
            // Long folded ear tip.
            line([
                CGPoint(x: 7, y: 27), CGPoint(x: 3, y: 24),
                CGPoint(x: 5, y: 20), CGPoint(x: 8, y: 22),
            ])
        case .queryowl:
            // Monocle lens and stem.
            context.strokeEllipse(in: CGRect(x: 17, y: 17, width: 7, height: 7))
            line([CGPoint(x: 23, y: 18), CGPoint(x: 27, y: 14)])
        case .relayray:
            // Twin signal fins.
            line([CGPoint(x: 8, y: 23), CGPoint(x: 3, y: 28), CGPoint(x: 9, y: 27)])
            line([CGPoint(x: 24, y: 23), CGPoint(x: 29, y: 28), CGPoint(x: 23, y: 27)])
        case .stackfox:
            // A second, blocky tail.
            line([
                CGPoint(x: 23, y: 12), CGPoint(x: 29, y: 9),
                CGPoint(x: 31, y: 13), CGPoint(x: 27, y: 16),
            ])
        default:
            break
        }
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
