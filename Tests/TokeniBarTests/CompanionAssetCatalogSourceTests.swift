import AppKit
import Foundation
import Testing
@testable import TokeniBar
import TokeniCore

@MainActor
struct CompanionAssetCatalogSourceTests {
    @Test("Missing and incompatible asset sources fail soft")
    func invalidSourcesFailSoft() {
        let source = CompanionAssetSource(
            id: .localImports,
            kind: .localImport,
            locations: [
                CompanionAssetLocation(
                    sourceID: .localImports,
                    packID: CompanionAssetPackID(rawValue: "missing.pack"),
                    speciesID: CompanionSpeciesID(
                        rawValue: "missing.pack.pet"),
                    format: .codexV2,
                    directoryURL: URL(fileURLWithPath: "/missing/pet")),
            ])
        let catalog = CompanionAssetCatalog(assetSources: [source])

        #expect(catalog.animation(
            for: .bytebot,
            behavior: .idle)?.frameCount == nil)
        #expect(catalog.frame(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            variantID: .standard,
            behavior: .idle,
            index: 0)?.width == nil)
    }

    @Test("Codex v2 packs map behavior rows and retain rectangular frames")
    func codexV2PackRendering() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "tokeni-catalog-\(UUID().uuidString)",
            directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)

        let packID = CompanionAssetPackID(rawValue: "codex.test-pet")
        let speciesID = CompanionSpeciesID(rawValue: "codex.test-pet")
        let metadata = InstalledCompanionAssetPack(
            packID: packID,
            speciesID: speciesID,
            displayName: "Test Pet",
            description: nil,
            format: .codexV2,
            spritesheetFileName: "spritesheet.png",
            provenance: .init(),
            installedAt: Date(timeIntervalSince1970: 0))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(metadata).write(to: root.appending(
            path: InstalledCompanionAssetPack.metadataFileName))
        try Self.writeTransparentPNG(
            width: CodexPetPackValidator.atlasColumns
                * CodexPetPackValidator.frameWidth,
            height: 11 * CodexPetPackValidator.frameHeight,
            to: root.appending(path: "spritesheet.png"))

        let catalog = CompanionAssetCatalog(assetSources: [
            CompanionAssetSource(
                id: .localImports,
                kind: .localImport,
                locations: [
                    CompanionAssetLocation(
                        sourceID: .localImports,
                        packID: packID,
                        speciesID: speciesID,
                        format: .codexV2,
                        directoryURL: root),
                ]),
        ])

        #expect(catalog.displayName(for: speciesID) == "Test Pet")
        #expect(catalog.animation(
            for: speciesID,
            behavior: .working) == CompanionRenderAnimation(
                row: 8,
                frameCount: 6,
                framesPerSecond: 6,
                loops: true))
        #expect(catalog.animation(
            for: speciesID,
            behavior: .sleep)?.frameCount == 1)
        let frame = catalog.frame(
            speciesID: speciesID,
            stage: .adult,
            rarity: .legendary,
            variantID: .mutated,
            behavior: .warning,
            index: 7)
        #expect(frame?.width == CodexPetPackValidator.frameWidth)
        #expect(frame?.height == CodexPetPackValidator.frameHeight)
    }

    private static func writeTransparentPNG(
        width: Int,
        height: Int,
        to url: URL) throws
    {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let image = context.makeImage(),
            let data = NSBitmapImageRep(cgImage: image).representation(
                using: .png,
                properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
    }
}
