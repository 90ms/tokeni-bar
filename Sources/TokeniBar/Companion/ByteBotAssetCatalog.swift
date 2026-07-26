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
        for fileName in Set(manifest.forms.values) {
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
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        behavior: CompanionBehavior,
        index: Int) -> CGImage?
    {
        guard let manifest,
              let sheetName = manifest.sheetName(for: stage, rarity: rarity),
              let sheet = self.sheets[sheetName],
              let animation = manifest.animation(for: behavior)
        else {
            return nil
        }

        let frameWidth = sheet.width / manifest.columns
        let frameHeight = sheet.height / manifest.rows
        guard frameWidth > 0, frameHeight > 0 else { return nil }
        let column = min(max(index, 0), max(animation.frameCount - 1, 0))
        let x = column * frameWidth
        let y = animation.row * frameHeight
        guard x >= 0,
              y >= 0,
              x + frameWidth <= sheet.width,
              y + frameHeight <= sheet.height
        else {
            return nil
        }
        return sheet.cropping(to: CGRect(
            x: x,
            y: y,
            width: frameWidth,
            height: frameHeight))
    }

    private static func assetDirectory() -> URL? {
        let relativeComponents = ["CompanionAssets", "bytebot"]
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
