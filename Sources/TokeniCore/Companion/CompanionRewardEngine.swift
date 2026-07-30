import Foundation

public struct CompanionRewardRules: Sendable {
    public static let standard = CompanionRewardRules(
        dailyAttendance: 10,
        weeklyAttendance: [3: 10, 5: 20, 7: 30],
        monthlyAttendanceDays: 20,
        monthlyAttendanceReward: 50,
        speciesDiscovery: 20,
        variantDiscovery: [.prismatic: 50],
        journeyCompletion: 25,
        collectionVariants: [5: 20, 10: 100],
        dailyVerifiedGrowth: 5,
        releaseGift: 20)

    public let dailyAttendance: Int
    public let weeklyAttendance: [Int: Int]
    public let monthlyAttendanceDays: Int
    public let monthlyAttendanceReward: Int
    public let speciesDiscovery: Int
    public let variantDiscovery: [CompanionVariantID: Int]
    public let journeyCompletion: Int
    public let collectionVariants: [Int: Int]
    public let dailyVerifiedGrowth: Int
    public let releaseGift: Int

    public init(
        dailyAttendance: Int,
        weeklyAttendance: [Int: Int],
        monthlyAttendanceDays: Int,
        monthlyAttendanceReward: Int,
        speciesDiscovery: Int,
        variantDiscovery: [CompanionVariantID: Int],
        journeyCompletion: Int,
        collectionVariants: [Int: Int],
        dailyVerifiedGrowth: Int,
        releaseGift: Int)
    {
        self.dailyAttendance = max(dailyAttendance, 0)
        self.weeklyAttendance = weeklyAttendance.reduce(into: [:]) { result, entry in
            if entry.key > 0, entry.value >= 0 {
                result[entry.key] = entry.value
            }
        }
        self.monthlyAttendanceDays = max(monthlyAttendanceDays, 1)
        self.monthlyAttendanceReward = max(monthlyAttendanceReward, 0)
        self.speciesDiscovery = max(speciesDiscovery, 0)
        self.variantDiscovery = variantDiscovery.mapValues { max($0, 0) }
        self.journeyCompletion = max(journeyCompletion, 0)
        self.collectionVariants = collectionVariants.reduce(into: [:]) {
            result, entry in
            if entry.key > 0, entry.value >= 0 {
                result[entry.key] = entry.value
            }
        }
        self.dailyVerifiedGrowth = max(dailyVerifiedGrowth, 0)
        self.releaseGift = max(releaseGift, 0)
    }
}

public struct CompanionRewardEngine: Sendable {
    public let rules: CompanionRewardRules
    public let cosmetics: [CompanionCosmetic]
    private var calendar: Calendar

    public init(
        rules: CompanionRewardRules = .standard,
        cosmetics: [CompanionCosmetic] = [
            CompanionCosmetic(id: .sparkleAura, cost: 60),
            CompanionCosmetic(id: .pixelHearts, cost: 80),
            CompanionCosmetic(id: .azurePalette, cost: 90),
            CompanionCosmetic(id: .developerHeadphones, cost: 100),
            CompanionCosmetic(id: .violetPalette, cost: 110),
            CompanionCosmetic(id: .starCrown, cost: 120),
            CompanionCosmetic(id: .wizardHat, cost: 140),
            CompanionCosmetic(id: .terminalNight, cost: 160),
            CompanionCosmetic(id: .nightRing, cost: 200),
            CompanionCosmetic(id: .cloudGarden, cost: 220),
        ],
        calendar: Calendar = .current)
    {
        self.rules = rules
        self.cosmetics = cosmetics
        self.calendar = calendar
    }

    public func attendanceStatus(
        at date: Date = .now,
        in state: CompanionRewardState) -> CompanionAttendanceStatus
    {
        let dateKey = GrowthLocalDate.key(for: date, calendar: self.calendar)
        if let latest = state.latestObservedDateKey, dateKey < latest {
            return .clockRollback
        }
        return state.attendanceRecords.contains { $0.dateKey == dateKey }
            ? .claimed
            : .available
    }

    public func attendanceCountThisWeek(
        at date: Date = .now,
        in state: CompanionRewardState) -> Int
    {
        let key = self.weekKey(for: date)
        return state.attendanceRecords.count { $0.weekKey == key }
    }

    public func attendanceCountThisMonth(
        at date: Date = .now,
        in state: CompanionRewardState) -> Int
    {
        let key = self.monthKey(for: date)
        return state.attendanceRecords.count { $0.monthKey == key }
    }

    public func checkIn(
        at date: Date = .now,
        in state: inout CompanionRewardState) throws -> [CompanionRewardGrant]
    {
        let dateKey = GrowthLocalDate.key(for: date, calendar: self.calendar)
        if let latest = state.latestObservedDateKey, dateKey < latest {
            throw CompanionRewardError.clockRollback
        }
        guard !state.attendanceRecords.contains(where: { $0.dateKey == dateKey }) else {
            throw CompanionRewardError.alreadyClaimed
        }

        let weekKey = self.weekKey(for: date)
        let monthKey = self.monthKey(for: date)
        state.attendanceRecords.append(CompanionAttendanceRecord(
            dateKey: dateKey,
            weekKey: weekKey,
            monthKey: monthKey,
            claimedAt: date))
        state.attendanceRecords = Array(state.attendanceRecords.suffix(400))
        state.latestObservedDateKey = max(state.latestObservedDateKey ?? dateKey, dateKey)

        var grants = [
            CompanionRewardGrant(
                amount: self.rules.dailyAttendance,
                reason: .dailyAttendance),
        ]
        let weeklyCount = state.attendanceRecords.count { $0.weekKey == weekKey }
        for threshold in self.rules.weeklyAttendance.keys.sorted() where weeklyCount >= threshold {
            let milestoneID = "attendance.week.\(weekKey).\(threshold)"
            guard state.awardedMilestoneIDs.insert(milestoneID).inserted else { continue }
            grants.append(CompanionRewardGrant(
                amount: self.rules.weeklyAttendance[threshold, default: 0],
                reason: .weeklyAttendance(days: threshold)))
        }

        let monthlyCount = state.attendanceRecords.count { $0.monthKey == monthKey }
        if monthlyCount >= self.rules.monthlyAttendanceDays {
            let milestoneID = "attendance.month.\(monthKey).\(self.rules.monthlyAttendanceDays)"
            if state.awardedMilestoneIDs.insert(milestoneID).inserted {
                grants.append(CompanionRewardGrant(
                    amount: self.rules.monthlyAttendanceReward,
                    reason: .monthlyAttendance(days: self.rules.monthlyAttendanceDays)))
            }
        }
        self.apply(grants, at: date, to: &state)
        return grants
    }

    public func reconcile(
        collection: CompanionCollection,
        at date: Date = .now,
        in state: inout CompanionRewardState) -> [CompanionRewardGrant]
    {
        var grants: [CompanionRewardGrant] = []
        for speciesID in collection.discoveredSpeciesIDs
            .subtracting(state.rewardedSpeciesIDs)
            .sorted(by: { $0.rawValue < $1.rawValue })
        {
            state.rewardedSpeciesIDs.insert(speciesID)
            grants.append(CompanionRewardGrant(
                amount: self.rules.speciesDiscovery,
                reason: .speciesDiscovered(speciesID)))
        }

        for variantID in self.rules.variantDiscovery.keys.sorted(by: {
            $0.rawValue < $1.rawValue
        }) where collection.discoveredVariantIDs.contains(variantID)
            && state.rewardedVariantIDs.insert(variantID).inserted
        {
            grants.append(CompanionRewardGrant(
                amount: self.rules.variantDiscovery[variantID, default: 0],
                reason: .variantDiscovered(variantID)))
        }

        if collection.totalCompletedGenerations > state.rewardedJourneyCount {
            let count = collection.totalCompletedGenerations - state.rewardedJourneyCount
            state.rewardedJourneyCount = collection.totalCompletedGenerations
            grants.append(CompanionRewardGrant(
                amount: Self.saturatedMultiply(self.rules.journeyCompletion, count),
                reason: .journeysCompleted(count)))
        }

        for threshold in self.rules.collectionVariants.keys.sorted()
            where collection.discoveredCollectibleVariantCount >= threshold
                && !state.rewardedFormMilestones.contains(threshold)
        {
            state.rewardedFormMilestones.insert(threshold)
            grants.append(CompanionRewardGrant(
                amount: self.rules.collectionVariants[threshold, default: 0],
                reason: .collectionVariants(threshold)))
        }

        self.apply(grants, at: date, to: &state)
        return grants
    }

    public func rewardVerifiedGrowth(
        energy: Int,
        at date: Date = .now,
        in state: inout CompanionRewardState) -> CompanionRewardGrant?
    {
        guard energy > 0 else { return nil }
        let dateKey = GrowthLocalDate.key(for: date, calendar: self.calendar)
        if let latest = state.latestObservedDateKey, dateKey < latest {
            return nil
        }
        guard !state.rewardedGrowthDateKeys.contains(dateKey) else { return nil }
        state.rewardedGrowthDateKeys.append(dateKey)
        state.rewardedGrowthDateKeys = Array(
            state.rewardedGrowthDateKeys.suffix(400))
        state.latestObservedDateKey = max(state.latestObservedDateKey ?? dateKey, dateKey)
        let grant = CompanionRewardGrant(
            amount: self.rules.dailyVerifiedGrowth,
            reason: .verifiedGrowth(dateKey: dateKey))
        self.apply([grant], at: date, to: &state)
        return grant
    }

    public func claimReleaseGift(
        appVersion: String,
        at date: Date = .now,
        in state: inout CompanionRewardState) -> CompanionRewardGrant?
    {
        guard let current = SemanticVersion(appVersion),
              current.prerelease.isEmpty
        else { return nil }
        if let previousValue = state.latestRewardedAppVersion,
           let previous = SemanticVersion(previousValue),
           current <= previous
        {
            return nil
        }
        state.latestRewardedAppVersion = current.description
        let grant = CompanionRewardGrant(
            amount: self.rules.releaseGift,
            reason: .releaseGift(version: current.description))
        self.apply([grant], at: date, to: &state)
        return grant
    }

    public func purchase(
        cosmeticID: CompanionCosmeticID,
        at date: Date = .now,
        in state: inout CompanionRewardState) throws
    {
        guard let cosmetic = self.cosmetics.first(where: { $0.id == cosmeticID }) else {
            throw CompanionRewardError.unknownCosmetic
        }
        guard !state.unlockedCosmeticIDs.contains(cosmeticID) else {
            throw CompanionRewardError.cosmeticAlreadyOwned
        }
        guard state.starShards >= cosmetic.cost else {
            throw CompanionRewardError.insufficientStarShards
        }

        state.starShards -= cosmetic.cost
        state.unlockedCosmeticIDs.insert(cosmeticID)
        state.selectedCosmeticIDs = Set(state.selectedCosmeticIDs.filter {
            $0.slot != cosmeticID.slot
        })
        state.selectedCosmeticIDs.insert(cosmeticID)
        state.updatedAt = date
    }

    public func select(
        cosmeticID: CompanionCosmeticID,
        at date: Date = .now,
        in state: inout CompanionRewardState) throws
    {
        guard state.unlockedCosmeticIDs.contains(cosmeticID) else {
            throw CompanionRewardError.cosmeticNotOwned
        }
        state.selectedCosmeticIDs = Set(state.selectedCosmeticIDs.filter {
            $0.slot != cosmeticID.slot
        })
        state.selectedCosmeticIDs.insert(cosmeticID)
        state.updatedAt = date
    }

    public func unequip(
        slot: CompanionCosmeticSlot,
        at date: Date = .now,
        in state: inout CompanionRewardState)
    {
        state.selectedCosmeticIDs = Set(state.selectedCosmeticIDs.filter {
            $0.slot != slot
        })
        state.updatedAt = date
    }

    public func grantBenefitShards(
        _ amount: Int,
        benefitID: CompanionBenefitID,
        at date: Date = .now,
        in state: inout CompanionRewardState) -> CompanionRewardGrant?
    {
        guard amount > 0 else { return nil }
        let grant = CompanionRewardGrant(
            amount: amount,
            reason: .benefit(benefitID))
        self.apply([grant], at: date, to: &state)
        return grant
    }

    private func apply(
        _ grants: [CompanionRewardGrant],
        at date: Date,
        to state: inout CompanionRewardState)
    {
        for grant in grants {
            state.starShards = Self.saturatedAdd(state.starShards, grant.amount)
        }
        if !grants.isEmpty {
            state.updatedAt = date
        }
    }

    private func weekKey(for date: Date) -> String {
        let components = self.calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date)
        return String(
            format: "%04d-W%02d",
            components.yearForWeekOfYear ?? 0,
            components.weekOfYear ?? 0)
    }

    private func monthKey(for date: Date) -> String {
        let components = self.calendar.dateComponents([.year, .month], from: date)
        return String(
            format: "%04d-%02d",
            components.year ?? 0,
            components.month ?? 0)
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }

    private static func saturatedMultiply(_ lhs: Int, _ rhs: Int) -> Int {
        let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? Int.max : product
    }
}
