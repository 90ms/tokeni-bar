import Foundation

/// A visual mutation discovered by combining duplicate companions.
/// Mutations never affect growth, odds, benefits, or resale value.
public struct CompanionMutationID:
    RawRepresentable, Codable, Hashable, Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let neon = Self(rawValue: "neon")
    public static let shadow = Self(rawValue: "shadow")
    public static let crystal = Self(rawValue: "crystal")
    public static let glitch = Self(rawValue: "glitch")
    public static let aurora = Self(rawValue: "aurora")
}

public struct CompanionMutationDefinition: Identifiable, Hashable, Sendable {
    public let id: CompanionMutationID
    public let isVisualOnly: Bool

    public init(id: CompanionMutationID, isVisualOnly: Bool = true) {
        self.id = id
        self.isVisualOnly = isVisualOnly
    }
}

public enum CompanionMutationRegistry {
    public static let synthesisSourceCount = 3
    public static let pitySynthesisCount = 3

    public static let definitions: [CompanionMutationDefinition] = [
        CompanionMutationDefinition(id: .neon),
        CompanionMutationDefinition(id: .shadow),
        CompanionMutationDefinition(id: .crystal),
        CompanionMutationDefinition(id: .glitch),
        CompanionMutationDefinition(id: .aurora),
    ]

    public static var allIDs: [CompanionMutationID] {
        self.definitions.map(\.id)
    }

    public static func definition(
        for id: CompanionMutationID) -> CompanionMutationDefinition?
    {
        self.definitions.first { $0.id == id }
    }

    public static func key(
        speciesID: CompanionSpeciesID,
        mutationID: CompanionMutationID) -> String
    {
        "\(speciesID.rawValue).\(mutationID.rawValue)"
    }

    /// Only standard, mutation-free companions can be consumed by the lab.
    /// This keeps prismatic discoveries and previously synthesized companions
    /// permanently out of the synthesis material pool.
    public static func isEligibleSource(
        _ generation: CompletedCompanionGeneration) -> Bool
    {
        generation.mutationID == nil
            && (generation.variantID
                ?? CompanionVariantRegistry.migrated(
                    from: generation.finalRarity)) == .standard
    }

    public static func roll(
        from candidates: [CompanionMutationID],
        unitValue requestedValue: Double) -> CompanionMutationID
    {
        let available = candidates.isEmpty ? Self.allIDs : candidates
        let value = min(max(requestedValue, 0), 0.999_999_999_999)
        let index = min(
            Int(floor(value * Double(available.count))),
            available.count - 1)
        return available[index]
    }
}

public struct CompanionMutationRecord: Codable, Hashable, Identifiable, Sendable {
    public let speciesID: CompanionSpeciesID
    public let mutationID: CompanionMutationID
    public let firstDiscoveredAt: Date
    public var lastSynthesizedAt: Date
    public var synthesisCount: Int

    public var id: String {
        CompanionMutationRegistry.key(
            speciesID: self.speciesID,
            mutationID: self.mutationID)
    }

    public init(
        speciesID: CompanionSpeciesID,
        mutationID: CompanionMutationID,
        firstDiscoveredAt: Date,
        lastSynthesizedAt: Date,
        synthesisCount: Int = 1)
    {
        self.speciesID = speciesID
        self.mutationID = mutationID
        self.firstDiscoveredAt = firstDiscoveredAt
        self.lastSynthesizedAt = lastSynthesizedAt
        self.synthesisCount = max(synthesisCount, 1)
    }
}
