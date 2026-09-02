import Foundation

public struct CompanionAssetSourceID:
    RawRepresentable, Codable, Hashable, Sendable
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

    public static let tokeniBundle = Self(rawValue: "tokeni.bundle")
    public static let localImports = Self(rawValue: "tokeni.local-imports")
}

public enum CompanionAssetSourceKind: String, Codable, Hashable, Sendable {
    case bundled
    case localImport
}

public enum CompanionAssetFormat: String, Codable, Hashable, Sendable {
    case tokeniNative
    case codexV1
    case codexV2
}

/// A validated runtime location for one species inside an asset pack.
///
/// Locations never participate in progression and contain no provider or usage
/// data. Importers are responsible for validating a directory before creating
/// a location for it.
public struct CompanionAssetLocation: Hashable, Sendable {
    public let sourceID: CompanionAssetSourceID
    public let packID: CompanionAssetPackID
    public let speciesID: CompanionSpeciesID
    public let format: CompanionAssetFormat
    public let directoryURL: URL

    public init(
        sourceID: CompanionAssetSourceID,
        packID: CompanionAssetPackID,
        speciesID: CompanionSpeciesID,
        format: CompanionAssetFormat,
        directoryURL: URL)
    {
        self.sourceID = sourceID
        self.packID = packID
        self.speciesID = speciesID
        self.format = format
        self.directoryURL = directoryURL
    }
}

public struct CompanionAssetSource: Hashable, Sendable {
    public let id: CompanionAssetSourceID
    public let kind: CompanionAssetSourceKind
    public let locations: [CompanionAssetLocation]

    public init(
        id: CompanionAssetSourceID,
        kind: CompanionAssetSourceKind,
        locations: [CompanionAssetLocation])
    {
        self.id = id
        self.kind = kind
        self.locations = locations.filter { $0.sourceID == id }
    }
}

/// Resolves validated asset locations in source order. The first exact
/// pack/species match wins, so imported content cannot shadow bundled artwork
/// merely by reusing a species identifier.
public struct CompanionAssetSourceRegistry: Sendable {
    public let sources: [CompanionAssetSource]

    public init(sources: [CompanionAssetSource]) {
        self.sources = sources
    }

    public var locations: [CompanionAssetLocation] {
        self.sources.flatMap(\.locations)
    }

    public func location(
        packID: CompanionAssetPackID,
        speciesID: CompanionSpeciesID) -> CompanionAssetLocation?
    {
        self.locations.first {
            $0.packID == packID && $0.speciesID == speciesID
        }
    }
}
