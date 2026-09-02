import Foundation

/// A stable companion identifier shared by bundled and imported pet content.
///
/// The raw value is persisted as a single JSON string. Keeping the identifier
/// open-ended lets a locally installed pack survive state decoding without
/// making third-party species part of the bundled hatch pool automatically.
public struct CompanionSpeciesID:
    RawRepresentable, Codable, CaseIterable, Hashable, Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    public static let bytebot = Self(rawValue: "bytebot")
    public static let cachecat = Self(rawValue: "cachecat")
    public static let stackfox = Self(rawValue: "stackfox")
    public static let promptpup = Self(rawValue: "promptpup")
    public static let nullslime = Self(rawValue: "nullslime")
    public static let queryowl = Self(rawValue: "queryowl")
    public static let patchpanda = Self(rawValue: "patchpanda")
    public static let loophare = Self(rawValue: "loophare")
    public static let relayray = Self(rawValue: "relayray")
    public static let kernelcrab = Self(rawValue: "kernelcrab")

    /// Bundled species only. Imported pack species are supplied by their
    /// content source and never enter the default game pool implicitly.
    public static var allCases: [Self] {
        CompanionSpeciesRegistry.speciesIDs
    }

    /// The bundled asset release generation, or `nil` for an external ID that
    /// has not been resolved by a content source.
    public var registeredContentGeneration: Int? {
        CompanionSpeciesRegistry.definition(for: self)?.contentGeneration
    }

    /// The asset release generation this species belongs to.
    ///
    /// Zero means the identifier is not registered as bundled content. This
    /// compatibility property is intentionally independent from a player's
    /// completed journeys; pack-aware UI should use its resolved definition.
    public var contentGeneration: Int {
        self.registeredContentGeneration ?? 0
    }

    public static func species(inContentGeneration generation: Int) -> [Self] {
        CompanionSpeciesRegistry.definitions.compactMap {
            $0.contentGeneration == generation ? $0.id : nil
        }
    }

    public static var latestContentGeneration: Int {
        CompanionSpeciesRegistry.definitions
            .map(\.contentGeneration)
            .max() ?? 1
    }

    public static var totalRegisteredFormCount: Int {
        CompanionSpeciesRegistry.definitions.count
            * CompanionVariantRegistry.definitions.count
            * CompanionGameStage.allCases.filter { $0 != .egg }.count
    }

    /// The player-facing collection target. Lifecycle sprites belong to a
    /// journey album and do not inflate the number of companions to discover.
    public static var totalCollectibleVariantCount: Int {
        CompanionSpeciesRegistry.definitions.count
            * CompanionVariantRegistry.collectibleIDs.count
    }

    public static var totalCollectibleMutationCount: Int {
        0
    }

    public static var totalCollectionEntryCount: Int {
        Self.totalCollectibleVariantCount
    }
}

public struct CompanionSpeciesDefinition: Identifiable, Hashable, Sendable {
    public let id: CompanionSpeciesID
    public let contentGeneration: Int

    public init(id: CompanionSpeciesID, contentGeneration: Int) {
        self.id = id
        self.contentGeneration = contentGeneration
    }
}

/// Definitions shipped with Tokeni. Installed packs will be layered on top by
/// a separate content source instead of mutating this deterministic game pool.
public enum CompanionSpeciesRegistry {
    public static let definitions: [CompanionSpeciesDefinition] = [
        CompanionSpeciesDefinition(id: .bytebot, contentGeneration: 1),
        CompanionSpeciesDefinition(id: .cachecat, contentGeneration: 1),
        CompanionSpeciesDefinition(id: .stackfox, contentGeneration: 1),
        CompanionSpeciesDefinition(id: .promptpup, contentGeneration: 1),
        CompanionSpeciesDefinition(id: .nullslime, contentGeneration: 1),
        CompanionSpeciesDefinition(id: .queryowl, contentGeneration: 2),
        CompanionSpeciesDefinition(id: .patchpanda, contentGeneration: 2),
        CompanionSpeciesDefinition(id: .loophare, contentGeneration: 2),
        CompanionSpeciesDefinition(id: .relayray, contentGeneration: 2),
        CompanionSpeciesDefinition(id: .kernelcrab, contentGeneration: 2),
    ]

    public static let speciesIDs = Self.definitions.map(\.id)

    public static func definition(
        for speciesID: CompanionSpeciesID) -> CompanionSpeciesDefinition?
    {
        Self.definitions.first { $0.id == speciesID }
    }
}
