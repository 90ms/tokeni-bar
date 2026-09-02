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
}
