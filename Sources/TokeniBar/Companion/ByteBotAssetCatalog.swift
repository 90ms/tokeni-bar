import AppKit
import Foundation
import TokeniCore

@MainActor
final class ByteBotAssetCatalog {
    static let shared = ByteBotAssetCatalog()

    let manifest: CompanionSpriteManifest?
    private let sheets: [String: CGImage]

    private init() {
        guard let assetDirectory = Self.assetDirectory(),
              let manifest = Self.loadManifest(from: assetDirectory)
        else {
            self.manifest = nil
            self.sheets = [:]
            return
        }

        self.manifest = manifest
        var loadedSheets: [String: CGImage] = [:]
        for fileName in Set(manifest.stages.values) {
            let fileURL = assetDirectory.appending(path: fileName)
            guard let image = NSImage(contentsOf: fileURL),
                  let cgImage = image.cgImage(
                      forProposedRect: nil,
                      context: nil,
                      hints: nil)
            else {
                continue
            }
            loadedSheets[fileName] = cgImage
        }
        self.sheets = loadedSheets
    }

    func frame(
        stage: CompanionStage,
        behavior: CompanionBehavior,
        index: Int) -> CGImage?
    {
        guard let manifest,
              let sheetName = manifest.sheetName(for: stage),
              let sheet = self.sheets[sheetName],
              let animation = manifest.animation(for: behavior)
        else {
            return nil
        }

        let frameSize = manifest.assetFrameSize
        let column = min(max(index, 0), max(animation.frameCount - 1, 0))
        let x = column * frameSize
        let y = animation.row * frameSize
        guard x >= 0,
              y >= 0,
              x + frameSize <= sheet.width,
              y + frameSize <= sheet.height
        else {
            return nil
        }
        return sheet.cropping(to: CGRect(
            x: x,
            y: y,
            width: frameSize,
            height: frameSize))
    }

    private static func assetDirectory() -> URL? {
        let relativeComponents = ["CompanionAssets", "bytebot"]
        let roots = [Bundle.main.resourceURL, Bundle.module.resourceURL].compactMap { $0 }
        for root in roots {
            let candidate = relativeComponents.reduce(root) {
                $0.appending(path: $1, directoryHint: .isDirectory)
            }
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static func loadManifest(from directory: URL) -> CompanionSpriteManifest? {
        let url = directory.appending(path: "manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(
                  CompanionSpriteManifest.self,
                  from: data),
              manifest.schemaVersion == 1,
              manifest.assetFrameSize > 0,
              manifest.columns > 0,
              manifest.rows > 0
        else {
            return nil
        }
        return manifest
    }
}
