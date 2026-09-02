import AppKit
import Dispatch
import Foundation
import TokeniCore

@MainActor
final class CompanionAssetCatalog {
    static let shared = CompanionAssetCatalog()

    private var assets: [CompanionSpeciesID: RenderAsset]
    private var assetDirectories: [CompanionSpeciesID: URL]
    private let sheetCache = NSCache<NSString, ImageBox>()
    private let frameCache = NSCache<NSString, ImageBox>()
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private convenience init() {
        self.init(assetSources: Self.defaultAssetSources())
    }

    init(assetSources: [CompanionAssetSource]) {
        let loaded = Self.loadAssets(from: assetSources)
        self.assets = loaded.assets
        self.assetDirectories = loaded.directories
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

    func reloadInstalledAssets() {
        let reloaded = Self.loadAssets(from: Self.defaultAssetSources())
        self.assets = reloaded.assets
        self.assetDirectories = reloaded.directories
        self.removeCachedImages()
    }

    func displayName(for speciesID: CompanionSpeciesID) -> String {
        self.assets[speciesID]?.displayName
            ?? AppLocalization.string(
                "companion.species.\(speciesID.rawValue).name")
    }

    func animation(
        for speciesID: CompanionSpeciesID?,
        behavior: CompanionBehavior) -> CompanionRenderAnimation?
    {
        self.asset(for: speciesID)?.animation(for: behavior)
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
        guard let asset = self.assets[speciesID],
              let sheetName = asset.sheetName(
                  for: stage,
                  variantID: variantID,
                  fallbackRarity: rarity),
              let animation = asset.animation(for: behavior)
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

        let frameWidth = sheet.width / asset.columns
        let frameHeight = sheet.height / asset.rows
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
                palette: asset.palette,
                mutatedSpeciesID: asset.supportsMutation
                    && variantID == .mutated && stage != .egg
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

    private func asset(
        for speciesID: CompanionSpeciesID?) -> RenderAsset?
    {
        self.assets[speciesID ?? .bytebot]
    }

    private static func defaultAssetSources() -> [CompanionAssetSource] {
        [
            Self.bundledAssetSource(),
            InstalledCompanionAssetPackStore().assetSource(),
        ]
    }

    private static func loadAssets(
        from sources: [CompanionAssetSource]
    ) -> (
        assets: [CompanionSpeciesID: RenderAsset],
        directories: [CompanionSpeciesID: URL]
    ) {
        var assets: [CompanionSpeciesID: RenderAsset] = [:]
        var directories: [CompanionSpeciesID: URL] = [:]
        for location in CompanionAssetSourceRegistry(sources: sources).locations {
            guard assets[location.speciesID] == nil,
                  let asset = Self.loadAsset(from: location)
            else { continue }
            assets[location.speciesID] = asset
            directories[location.speciesID] = location.directoryURL
        }
        return (assets, directories)
    }

    private static func bundledAssetSource() -> CompanionAssetSource {
        let locations = CompanionSpeciesRegistry.gameDefinitions.compactMap {
            definition -> CompanionAssetLocation? in
            guard let directory = Self.bundledAssetDirectory(
                for: definition.id)
            else { return nil }
            return CompanionAssetLocation(
                sourceID: .tokeniBundle,
                packID: definition.assetPackID,
                speciesID: definition.id,
                format: .tokeniNative,
                directoryURL: directory)
        }
        return CompanionAssetSource(
            id: .tokeniBundle,
            kind: .bundled,
            locations: locations)
    }

    private static func bundledAssetDirectory(
        for speciesID: CompanionSpeciesID) -> URL?
    {
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

    private static func loadAsset(
        from location: CompanionAssetLocation
    ) -> RenderAsset? {
        switch location.format {
        case .tokeniNative:
            guard let manifest = Self.loadManifest(
                from: location.directoryURL)
            else { return nil }
            return .native(manifest)
        case .codexV1, .codexV2:
            let metadataURL = location.directoryURL.appending(
                path: InstalledCompanionAssetPack.metadataFileName)
            guard let data = try? Data(
                contentsOf: metadataURL,
                options: [.mappedIfSafe])
            else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let metadata = try? decoder.decode(
                InstalledCompanionAssetPack.self,
                from: data),
                metadata.packID == location.packID,
                metadata.speciesID == location.speciesID,
                metadata.format == location.format,
                metadata.spritesheetFileName == "spritesheet.webp"
                    || metadata.spritesheetFileName == "spritesheet.png",
                FileManager.default.fileExists(atPath: location.directoryURL
                    .appending(path: metadata.spritesheetFileName).path)
            else { return nil }
            return .codex(CodexRenderAsset(
                displayName: metadata.displayName,
                sheetName: metadata.spritesheetFileName,
                rows: location.format == .codexV2 ? 11 : 9))
        }
    }
}

private enum RenderAsset {
    case native(CompanionSpriteManifest)
    case codex(CodexRenderAsset)

    var displayName: String {
        switch self {
        case let .native(manifest): manifest.displayName
        case let .codex(asset): asset.displayName
        }
    }

    var columns: Int {
        switch self {
        case let .native(manifest): manifest.columns
        case .codex: CodexPetPackValidator.atlasColumns
        }
    }

    var rows: Int {
        switch self {
        case let .native(manifest): manifest.rows
        case let .codex(asset): asset.rows
        }
    }

    var palette: [String] {
        switch self {
        case let .native(manifest): manifest.palette
        case .codex: []
        }
    }

    var supportsMutation: Bool {
        if case .native = self { return true }
        return false
    }

    func sheetName(
        for stage: CompanionGameStage,
        variantID: CompanionVariantID,
        fallbackRarity: CompanionRarity) -> String?
    {
        switch self {
        case let .native(manifest):
            manifest.sheetName(
                for: stage,
                variantID: variantID,
                fallbackRarity: fallbackRarity)
        case let .codex(asset): asset.sheetName
        }
    }

    func animation(for behavior: CompanionBehavior) -> CompanionRenderAnimation? {
        switch self {
        case let .native(manifest): manifest.animation(for: behavior)
        case let .codex(asset): asset.animation(for: behavior)
        }
    }
}

private struct CodexRenderAsset {
    let displayName: String
    let sheetName: String
    let rows: Int

    func animation(for behavior: CompanionBehavior) -> CompanionRenderAnimation {
        switch behavior {
        case .idle:
            CompanionRenderAnimation(
                row: 0, frameCount: 6, framesPerSecond: 2, loops: true)
        case .working:
            CompanionRenderAnimation(
                row: 8, frameCount: 6, framesPerSecond: 6, loops: true)
        case .waiting:
            CompanionRenderAnimation(
                row: 6, frameCount: 6, framesPerSecond: 3, loops: true)
        case .warning:
            CompanionRenderAnimation(
                row: 5, frameCount: 8, framesPerSecond: 6, loops: true)
        case .celebrate, .signature:
            CompanionRenderAnimation(
                row: 3, frameCount: 4, framesPerSecond: 5, loops: true)
        case .sleep:
            CompanionRenderAnimation(
                row: 0, frameCount: 1, framesPerSecond: 0, loops: false)
        }
    }
}

private final class ImageBox {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}
