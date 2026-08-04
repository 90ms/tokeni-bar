import Foundation

/// Provider-neutral, unbounded pet progression derived only from verified
/// growth awards.
public struct CompanionLevelCurve: Hashable, Sendable {
    public static let standard = CompanionLevelCurve(
        initialXP: 2,
        levelsPerStep: 10,
        stepXP: 1,
        maximumXPPerLevel: 15)

    public let initialXP: Int
    public let levelsPerStep: Int
    public let stepXP: Int
    public let maximumXPPerLevel: Int

    public init(
        initialXP: Int,
        levelsPerStep: Int,
        stepXP: Int,
        maximumXPPerLevel: Int)
    {
        self.initialXP = max(initialXP, 1)
        self.levelsPerStep = max(levelsPerStep, 1)
        self.stepXP = max(stepXP, 0)
        self.maximumXPPerLevel = max(maximumXPPerLevel, self.initialXP)
    }

    public func xpToNextLevel(from level: Int) -> Int {
        let normalizedLevel = max(level, 1)
        let step = (normalizedLevel - 1) / self.levelsPerStep
        return min(
            Self.saturatedAdd(
                self.initialXP,
                Self.saturatedMultiply(step, self.stepXP)),
            self.maximumXPPerLevel)
    }

    public func level(forXP xp: Int) -> Int {
        var remaining = max(xp, 0)
        var level = 1
        let firstCappedLevel = self.firstCappedLevel

        while level < firstCappedLevel {
            let required = self.xpToNextLevel(from: level)
            guard remaining >= required else { return level }
            remaining -= required
            level += 1
        }

        let additionalLevels = remaining / self.terminalXPPerLevel
        return Self.saturatedAdd(level, additionalLevels)
    }

    public func totalXPRequired(forLevel requestedLevel: Int) -> Int {
        let targetLevel = max(requestedLevel, 1)
        var total = 0
        var level = 1
        let rampEnd = min(targetLevel, self.firstCappedLevel)

        while level < rampEnd {
            total = Self.saturatedAdd(
                total,
                self.xpToNextLevel(from: level))
            level += 1
        }

        guard targetLevel > level else { return total }
        return Self.saturatedAdd(
            total,
            Self.saturatedMultiply(
                targetLevel - level,
                self.terminalXPPerLevel))
    }

    public func progress(forXP xp: Int) -> Double {
        let normalizedXP = max(xp, 0)
        let level = self.level(forXP: normalizedXP)
        let floorXP = self.totalXPRequired(forLevel: level)
        let required = self.xpToNextLevel(from: level)
        guard required > 0 else { return 0 }
        return min(max(Double(normalizedXP - floorXP) / Double(required), 0), 1)
    }

    public func xpIntoLevel(forXP xp: Int) -> Int {
        let normalizedXP = max(xp, 0)
        let level = self.level(forXP: normalizedXP)
        return max(
            normalizedXP - self.totalXPRequired(forLevel: level),
            0)
    }

    private var firstCappedLevel: Int {
        guard self.stepXP > 0 else { return 1 }
        let delta = self.maximumXPPerLevel - self.initialXP
        let completeSteps = delta / self.stepXP
        let steps = completeSteps + (delta % self.stepXP == 0 ? 0 : 1)
        return Self.saturatedAdd(
            Self.saturatedMultiply(steps, self.levelsPerStep),
            1)
    }

    private var terminalXPPerLevel: Int {
        self.stepXP == 0 ? self.initialXP : self.maximumXPPerLevel
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : value
    }

    private static func saturatedMultiply(_ lhs: Int, _ rhs: Int) -> Int {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? Int.max : value
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
        CompanionEvolutionDefinition(stage: .junior, requiredLevel: 10),
        CompanionEvolutionDefinition(stage: .adult, requiredLevel: 25),
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
