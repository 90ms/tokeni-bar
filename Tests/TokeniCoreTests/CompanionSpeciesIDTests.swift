import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion species identifiers")
struct CompanionSpeciesIDTests {
    @Test("Bundled identifiers keep their single-string persistence format")
    func bundledIdentifierPersistenceCompatibility() throws {
        let data = try JSONEncoder().encode(CompanionSpeciesID.bytebot)

        #expect(String(decoding: data, as: UTF8.self) == "\"bytebot\"")
        #expect(
            try JSONDecoder().decode(CompanionSpeciesID.self, from: data)
                == .bytebot)
    }

    @Test("External identifiers round-trip without entering the bundled pool")
    func externalIdentifierRoundTrip() throws {
        let external = CompanionSpeciesID(
            rawValue: "community.nebula-pack.nebujelly")
        let data = try JSONEncoder().encode(external)
        let decoded = try JSONDecoder().decode(
            CompanionSpeciesID.self,
            from: data)

        #expect(decoded == external)
        #expect(decoded.rawValue == "community.nebula-pack.nebujelly")
        #expect(decoded.registeredContentGeneration == nil)
        #expect(!CompanionSpeciesID.allCases.contains(decoded))
    }

    @Test("The bundled registry preserves the two existing generations")
    func bundledRegistryCompatibility() {
        #expect(CompanionSpeciesRegistry.definitions.count == 10)
        #expect(CompanionSpeciesRegistry.speciesIDs == [
            .bytebot,
            .cachecat,
            .stackfox,
            .promptpup,
            .nullslime,
            .queryowl,
            .patchpanda,
            .loophare,
            .relayray,
            .kernelcrab,
        ])
        #expect(
            CompanionSpeciesRegistry.definition(for: .queryowl)?
                .contentGeneration == 2)
        #expect(
            CompanionSpeciesRegistry.definition(for: .bytebot)?
                .assetPackID == .tokeniBundled)
        #expect(
            CompanionSpeciesRegistry.gameSpeciesIDs
                == CompanionSpeciesID.allCases)
    }

    @Test("Appearance-only definitions cannot opt into game progression")
    func appearanceOnlyDefinition() throws {
        let packID = CompanionAssetPackID(rawValue: "community.nebula-pack")
        let definition = CompanionSpeciesDefinition(
            id: CompanionSpeciesID(rawValue: "community.nebula-pack.nebujelly"),
            displayNameLocalizationKey: "Nebujelly",
            assetPackID: packID,
            gameEligibility: .appearanceOnly,
            contentGeneration: nil)

        #expect(definition.gameEligibility == .appearanceOnly)
        #expect(definition.contentGeneration == nil)
        #expect(String(
            decoding: try JSONEncoder().encode(packID),
            as: UTF8.self) == "\"community.nebula-pack\"")
    }
}
