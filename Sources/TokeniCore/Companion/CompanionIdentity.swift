import Foundation

/// Provider-neutral personality used only for presentation and reactions.
public struct CompanionPersonalityID:
    RawRepresentable, Codable, Hashable, Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let calm = Self(rawValue: "calm")
    public static let curious = Self(rawValue: "curious")
    public static let playful = Self(rawValue: "playful")
    public static let dreamy = Self(rawValue: "dreamy")
    public static let brave = Self(rawValue: "brave")
}

public enum CompanionPersonalityRegistry {
    public static let allIDs: [CompanionPersonalityID] = [
        .calm,
        .curious,
        .playful,
        .dreamy,
        .brave,
    ]

    public static func resolved(_ id: CompanionPersonalityID?)
        -> CompanionPersonalityID
    {
        guard let id, self.allIDs.contains(id) else { return .calm }
        return id
    }
}

public enum CompanionMemoryKind: String, Codable, Hashable, Sendable {
    case hatched
    case evolved
    case firstPat
    case bondLevel
    case journeyCompleted
}

/// A deliberately content-free memory. It records a pet event but never a
/// provider, token amount, prompt, response, or work-session content.
public struct CompanionMemoryRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let generationID: UUID
    public let kind: CompanionMemoryKind
    public let stage: CompanionGameStage
    public let bondLevel: Int?
    public let occurredAt: Date

    public init(
        id: UUID = UUID(),
        generationID: UUID,
        kind: CompanionMemoryKind,
        stage: CompanionGameStage,
        bondLevel: Int? = nil,
        occurredAt: Date)
    {
        self.id = id
        self.generationID = generationID
        self.kind = kind
        self.stage = stage
        self.bondLevel = bondLevel
        self.occurredAt = occurredAt
    }
}

public enum CompanionBond {
    public static let levelThresholds = [0, 50, 150, 400, 800]

    public static func level(for energy: Int) -> Int {
        self.levelThresholds.lastIndex { energy >= $0 }.map { $0 + 1 } ?? 1
    }

    public static func nextThreshold(after energy: Int) -> Int? {
        self.levelThresholds.first { $0 > energy }
    }
}

