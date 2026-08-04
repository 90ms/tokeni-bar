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
        behavior: CompanionBehavior,
        index: Int) -> CGImage?
    {
        let speciesID = stage == .egg
            ? CompanionSpeciesID.bytebot
            : requestedSpeciesID ?? .bytebot
        guard let manifest = self.manifests[speciesID],
              let sheetName = manifest.sheetName(for: stage, rarity: rarity),
              let animation = manifest.animation(for: behavior)
        else {
            return nil
        }

        let column = min(max(index, 0), max(animation.frameCount - 1, 0))
        let frameKey = NSString(string: [
            speciesID.rawValue,
            sheetName,
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
                height: frameHeight)
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
        height: Int) -> CGImage?
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
        return context.makeImage()
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
