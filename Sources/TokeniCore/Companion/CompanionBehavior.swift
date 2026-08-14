import Foundation

public enum CompanionBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case working
    case waiting
    case warning
    case celebrate
    case sleep
    /// A species-specific action available only to mutation appearances.
    case signature
}

public struct CompanionSpecialActionID:
    RawRepresentable, Codable, Hashable, Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct CompanionSpecialActionDefinition:
    Identifiable, Hashable, Sendable
{
    public let id: CompanionSpecialActionID
    public let speciesID: CompanionSpeciesID
    public let requiredVariantID: CompanionVariantID
    public let behavior: CompanionBehavior

    public init(
        id: CompanionSpecialActionID,
        speciesID: CompanionSpeciesID,
        requiredVariantID: CompanionVariantID,
        behavior: CompanionBehavior)
    {
        self.id = id
        self.speciesID = speciesID
        self.requiredVariantID = requiredVariantID
        self.behavior = behavior
    }
}

public enum CompanionSpecialActionRegistry {
    public static let definitions: [CompanionSpecialActionDefinition] = [
        Self.mutationAction("bytebot.reassemble", speciesID: .bytebot),
        Self.mutationAction("cachecat.data-chase", speciesID: .cachecat),
        Self.mutationAction("stackfox.afterimage", speciesID: .stackfox),
        Self.mutationAction("promptpup.command-trail", speciesID: .promptpup),
        Self.mutationAction("nullslime.reform", speciesID: .nullslime),
        Self.mutationAction("queryowl.signal-scan", speciesID: .queryowl),
        Self.mutationAction("patchpanda.pixel-mend", speciesID: .patchpanda),
        Self.mutationAction("loophare.recursive-dash", speciesID: .loophare),
        Self.mutationAction("relayray.packet-wave", speciesID: .relayray),
        Self.mutationAction("kernelcrab.core-open", speciesID: .kernelcrab),
    ]

    public static func action(
        for speciesID: CompanionSpeciesID,
        variantID: CompanionVariantID) -> CompanionSpecialActionDefinition?
    {
        self.definitions.first {
            $0.speciesID == speciesID
                && $0.requiredVariantID == variantID
        }
    }

    private static func mutationAction(
        _ rawValue: String,
        speciesID: CompanionSpeciesID) -> CompanionSpecialActionDefinition
    {
        CompanionSpecialActionDefinition(
            id: CompanionSpecialActionID(rawValue: rawValue),
            speciesID: speciesID,
            requiredVariantID: .mutated,
            behavior: .signature)
    }
}

public enum CompanionBehaviorResolver {
    public static func resolve(
        state: CompanionGameState,
        isWorking: Bool,
        lowestRemainingQuotaPercent: Double?,
        at now: Date = .now,
        warningThreshold: Double = 10,
        waitingFor: TimeInterval = 2 * 60,
        sleepAfter: TimeInterval = 10 * 60) -> CompanionBehavior
    {
        if state.celebrationUntil.map({ $0 > now }) == true {
            return .celebrate
        }
        if lowestRemainingQuotaPercent.map({ $0 <= warningThreshold }) == true {
            return .warning
        }
        if isWorking {
            return .working
        }
        if let lastActiveAt = state.lastActiveAt {
            let inactiveFor = now.timeIntervalSince(lastActiveAt)
            if inactiveFor >= max(sleepAfter, 0) {
                return .sleep
            }
            if inactiveFor >= 0, inactiveFor < max(waitingFor, 0) {
                return .waiting
            }
        }
        return .idle
    }
}
