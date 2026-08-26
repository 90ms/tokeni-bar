import Foundation

/// Provider-neutral pet progression derived only from verified growth awards.
///
/// The standard curve deliberately grows quickly at first and slows toward a
/// product maximum. `maximumLevel` and `totalXPAtMaximumLevel` are independent
/// policy values so a future release can extend the cap without changing the
/// verified-token conversion formula.
public struct CompanionLevelCurve: Hashable, Sendable {
    public static let standard = CompanionLevelCurve(
        maximumLevel: 100,
        totalXPAtMaximumLevel: 500,
        exponent: 1.7)

    public let maximumLevel: Int
    public let totalXPAtMaximumLevel: Int
    public let exponent: Double

    public init(
        maximumLevel: Int,
        totalXPAtMaximumLevel: Int,
        exponent: Double)
    {
        self.maximumLevel = max(maximumLevel, 2)
        self.totalXPAtMaximumLevel = max(
            totalXPAtMaximumLevel,
            self.maximumLevel - 1)
        self.exponent = max(exponent, 1)
    }

    public var maximumXP: Int {
        self.totalXPAtMaximumLevel
    }

    public func xpToNextLevel(from level: Int) -> Int {
        let normalizedLevel = min(max(level, 1), self.maximumLevel)
        guard normalizedLevel < self.maximumLevel else { return 0 }
        return max(
            self.totalXPRequired(forLevel: normalizedLevel + 1)
                - self.totalXPRequired(forLevel: normalizedLevel),
            1)
    }

    public func level(forXP xp: Int) -> Int {
        let normalizedXP = self.clampedXP(xp)
        var lower = 1
        var upper = self.maximumLevel
        while lower < upper {
            let middle = lower + (upper - lower + 1) / 2
            if self.totalXPRequired(forLevel: middle) <= normalizedXP {
                lower = middle
            } else {
                upper = middle - 1
            }
        }
        return lower
    }

    public func totalXPRequired(forLevel requestedLevel: Int) -> Int {
        let level = min(max(requestedLevel, 1), self.maximumLevel)
        guard level > 1 else { return 0 }
        guard level < self.maximumLevel else {
            return self.totalXPAtMaximumLevel
        }
        let progress = Double(level - 1) / Double(self.maximumLevel - 1)
        let curved = Int((Double(self.totalXPAtMaximumLevel)
            * pow(progress, self.exponent)).rounded())
        return min(max(curved, level - 1), self.totalXPAtMaximumLevel)
    }

    public func progress(forXP xp: Int) -> Double {
        let normalizedXP = self.clampedXP(xp)
        let level = self.level(forXP: normalizedXP)
        guard level < self.maximumLevel else { return 1 }
        let floorXP = self.totalXPRequired(forLevel: level)
        let required = self.xpToNextLevel(from: level)
        return min(max(Double(normalizedXP - floorXP) / Double(required), 0), 1)
    }

    public func xpIntoLevel(forXP xp: Int) -> Int {
        let normalizedXP = self.clampedXP(xp)
        let level = self.level(forXP: normalizedXP)
        guard level < self.maximumLevel else { return 0 }
        return max(
            normalizedXP - self.totalXPRequired(forLevel: level),
            0)
    }

    public func clampedXP(_ xp: Int) -> Int {
        min(max(xp, 0), self.maximumXP)
    }
}

public struct CompanionEvolutionDefinition: Identifiable, Hashable, Sendable {
    public let stage: CompanionGameStage
    public let requiredLevel: Int

    public var id: CompanionGameStage { self.stage }

    public init(stage: CompanionGameStage, requiredLevel: Int) {
        self.stage = stage
        self.requiredLevel = max(requiredLevel, 1)
    }
}

public enum CompanionEvolutionRegistry {
    public static let definitions: [CompanionEvolutionDefinition] = [
        CompanionEvolutionDefinition(stage: .hatchling, requiredLevel: 1),
        CompanionEvolutionDefinition(stage: .junior, requiredLevel: 30),
        CompanionEvolutionDefinition(stage: .adult, requiredLevel: 70),
    ]

    public static func requiredLevel(for stage: CompanionGameStage) -> Int? {
        self.definitions.first { $0.stage == stage }?.requiredLevel
    }

    public static func next(after stage: CompanionGameStage)
        -> CompanionEvolutionDefinition?
    {
        guard let index = self.definitions.firstIndex(where: {
            $0.stage == stage
        }) else { return self.definitions.first }
        let nextIndex = self.definitions.index(after: index)
        return nextIndex < self.definitions.endIndex
            ? self.definitions[nextIndex]
            : nil
    }
}
