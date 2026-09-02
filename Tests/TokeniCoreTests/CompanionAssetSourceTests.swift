import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion asset sources")
struct CompanionAssetSourceTests {
    @Test("Registry resolves an exact pack and species pair")
    func exactResolution() {
        let bundledURL = URL(fileURLWithPath: "/app/bytebot")
        let importedURL = URL(fileURLWithPath: "/imports/nebujelly")
        let importedPackID = CompanionAssetPackID(
            rawValue: "community.nebula-pack")
        let importedSpeciesID = CompanionSpeciesID(
            rawValue: "community.nebula-pack.nebujelly")
        let registry = CompanionAssetSourceRegistry(sources: [
            CompanionAssetSource(
                id: .tokeniBundle,
                kind: .bundled,
                locations: [
                    CompanionAssetLocation(
                        sourceID: .tokeniBundle,
                        packID: .tokeniBundled,
                        speciesID: .bytebot,
                        format: .tokeniNative,
                        directoryURL: bundledURL),
                ]),
            CompanionAssetSource(
                id: .localImports,
                kind: .localImport,
                locations: [
                    CompanionAssetLocation(
                        sourceID: .localImports,
                        packID: importedPackID,
                        speciesID: importedSpeciesID,
                        format: .codexV2,
                        directoryURL: importedURL),
                ]),
        ])

        #expect(registry.location(
            packID: .tokeniBundled,
            speciesID: .bytebot)?.directoryURL == bundledURL)
        #expect(registry.location(
            packID: importedPackID,
            speciesID: importedSpeciesID)?.directoryURL == importedURL)
        #expect(registry.location(
            packID: .tokeniBundled,
            speciesID: importedSpeciesID) == nil)
    }

    @Test("A source discards locations that claim another source")
    func mismatchedSourceIsDiscarded() {
        let source = CompanionAssetSource(
            id: .localImports,
            kind: .localImport,
            locations: [
                CompanionAssetLocation(
                    sourceID: .tokeniBundle,
                    packID: .tokeniBundled,
                    speciesID: .bytebot,
                    format: .tokeniNative,
                    directoryURL: URL(fileURLWithPath: "/unexpected")),
            ])

        #expect(source.locations.isEmpty)
    }

    @Test("The first exact source match wins deterministically")
    func firstSourceWins() {
        let firstURL = URL(fileURLWithPath: "/first")
        let secondURL = URL(fileURLWithPath: "/second")
        let first = self.source(id: .tokeniBundle, directoryURL: firstURL)
        let second = self.source(id: .localImports, directoryURL: secondURL)
        let registry = CompanionAssetSourceRegistry(sources: [first, second])

        #expect(registry.location(
            packID: .tokeniBundled,
            speciesID: .bytebot)?.directoryURL == firstURL)
    }

    private func source(
        id: CompanionAssetSourceID,
        directoryURL: URL) -> CompanionAssetSource
    {
        CompanionAssetSource(
            id: id,
            kind: id == .tokeniBundle ? .bundled : .localImport,
            locations: [
                CompanionAssetLocation(
                    sourceID: id,
                    packID: .tokeniBundled,
                    speciesID: .bytebot,
                    format: .tokeniNative,
                    directoryURL: directoryURL),
            ])
    }
}
