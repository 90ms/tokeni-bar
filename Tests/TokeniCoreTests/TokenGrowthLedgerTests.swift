import Foundation
import Testing
@testable import TokeniCore

@Suite("Token growth ledger")
struct TokenGrowthLedgerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("Aggregates providers before applying the linear conversion")
    func aggregatesProviders() throws {
        let now = try #require(self.date("2026-07-26T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        let awards = engine.process(
            observations: [
                self.daily(.codex, tokens: 50_000, at: now),
                self.daily(.claude, tokens: 50_000, at: now),
            ],
            at: now,
            in: &state)

        #expect(awards.map(\.energy) == [4])
        #expect(state.dayCredits.first?.aggregateTokens == 100_000)
        #expect(state.dayCredits.first?.targetEnergy == 4)
        #expect(state.pendingAwards == awards)
    }

    @Test("Repeated daily observations never pay twice")
    func dailyIdempotency() throws {
        let now = try #require(self.date("2026-07-26T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        let observation = self.daily(.claude, tokens: 100_000, at: now)
        var state = TokenGrowthLedgerState()

        let first = engine.process(observations: [observation], at: now, in: &state)
        let repeated = engine.process(observations: [observation], at: now, in: &state)
        let increased = engine.process(
            observations: [self.daily(.claude, tokens: 250_000, at: now)],
            at: now,
            in: &state)

        #expect(first.map(\.energy) == [4])
        #expect(repeated.isEmpty)
        #expect(increased.map(\.energy) == [6])
        #expect(state.dayCredits.first?.awardedEnergy == 10)
        #expect(state.conversionRemainderTokens == 0)
    }

    @Test("Sub-energy token remainder carries across dates")
    func conversionRemainderCarriesAcrossDates() throws {
        let firstDay = try #require(self.date("2026-07-26T12:00:00Z"))
        let nextDay = try #require(self.date("2026-07-27T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        let first = engine.process(
            observations: [
                self.daily(.codex, tokens: 60_000, at: firstDay),
            ],
            at: firstDay,
            in: &state)
        let second = engine.process(
            observations: [
                self.daily(.codex, tokens: 50_000, at: nextDay),
            ],
            at: nextDay,
            in: &state)

        #expect(first.map(\.energy) == [2])
        #expect(second.map(\.energy) == [2])
        #expect(state.conversionRemainderTokens == 10_000)
    }

    @Test("Version one ledgers migrate with an empty conversion remainder")
    func legacyLedgerMigration() throws {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "checkpoints": [],
              "providerDayTotals": [],
              "dayCredits": [],
              "pendingAwards": []
            }
            """.utf8)

        let decoded = try JSONDecoder().decode(
            TokenGrowthLedgerState.self,
            from: data)

        #expect(decoded.schemaVersion == TokenGrowthLedgerState.currentSchemaVersion)
        #expect(decoded.conversionRemainderTokens == 0)
    }

    @Test("A delayed daily bucket is credited to its original usage date")
    func delayedDailyBucket() throws {
        let usageDate = try #require(self.date("2026-07-27T12:00:00Z"))
        let observedAt = try #require(self.date("2026-07-28T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()
        let observation = GrowthUsageObservation.daily(
            providerID: .codex,
            dateKey: "2026-07-27",
            totalTokens: 352_031,
            observedAt: observedAt)

        let awards = engine.process(
            observations: [observation],
            at: observedAt,
            in: &state)

        #expect(awards.count == 1)
        #expect(awards.first?.dateKey == "2026-07-27")
        #expect(state.providerDayTotals == [
            GrowthProviderDayTotal(
                dateKey: "2026-07-27",
                providerID: .codex,
                tokens: 352_031,
                lastCreditedAt: observedAt),
        ])
        #expect(GrowthLocalDate.key(for: usageDate, calendar: self.calendar) == "2026-07-27")
    }

    @Test("A delayed daily total only adds energy beyond local session credit")
    func delayedDailyBucketReconcilesLocalCredit() throws {
        let usageDate = try #require(self.date("2026-07-27T12:00:00Z"))
        let confirmedAt = try #require(self.date("2026-07-28T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        _ = engine.process(
            observations: [
                self.session(
                    "local",
                    tokens: 10_000,
                    at: usageDate,
                    providerID: .codex),
            ],
            at: usageDate,
            in: &state)
        let localAward = engine.process(
            observations: [
                self.session(
                    "local",
                    tokens: 60_000,
                    at: usageDate,
                    providerID: .codex),
            ],
            at: usageDate,
            in: &state)
        let confirmedAward = engine.process(
            observations: [
                GrowthUsageObservation.daily(
                    providerID: .codex,
                    dateKey: "2026-07-27",
                    totalTokens: 100_000,
                    observedAt: confirmedAt),
            ],
            at: confirmedAt,
            in: &state)

        #expect(localAward.map(\.energy) == [2])
        #expect(confirmedAward.map(\.energy) == [2])
        #expect(state.dayCredits.first?.awardedEnergy == 4)
        #expect(state.providerDayTotals.first?.tokens == 100_000)
    }

    @Test("Daily buckets older than the late window are ignored")
    func rejectsExpiredDailyBucket() throws {
        let observedAt = try #require(self.date("2026-07-28T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        let awards = engine.process(
            observations: [
                GrowthUsageObservation.daily(
                    providerID: .codex,
                    dateKey: "2026-07-24",
                    totalTokens: 352_031,
                    observedAt: observedAt),
            ],
            at: observedAt,
            in: &state)

        #expect(awards.isEmpty)
        #expect(state.providerDayTotals.isEmpty)
    }

    @Test("Legacy provider totals decode without settlement metadata")
    func legacyProviderTotalDecoding() throws {
        let data = Data(
            #"{"dateKey":"2026-07-27","providerID":"codex","tokens":352031}"#.utf8)

        let decoded = try JSONDecoder().decode(
            GrowthProviderDayTotal.self,
            from: data)

        #expect(decoded.dateKey == "2026-07-27")
        #expect(decoded.providerID == .codex)
        #expect(decoded.tokens == 352_031)
        #expect(decoded.lastCreditedAt == nil)
    }

    @Test("Cumulative counters establish a baseline before awarding deltas")
    func cumulativeBaseline() throws {
        let now = try #require(self.date("2026-07-26T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        let baseline = GrowthUsageObservation(
            providerID: .openCode,
            scope: .lifetime,
            scopeID: "opencode.db",
            totalTokens: 2_000_000,
            observedAt: now)
        let first = engine.process(observations: [baseline], at: now, in: &state)
        let second = engine.process(
            observations: [
                GrowthUsageObservation(
                    providerID: .openCode,
                    scope: .lifetime,
                    scopeID: "opencode.db",
                    totalTokens: 2_100_000,
                    observedAt: now.addingTimeInterval(60)),
            ],
            at: now.addingTimeInterval(60),
            in: &state)

        #expect(first.isEmpty)
        #expect(second.map(\.energy) == [4])
    }

    @Test("New sessions and new dates cannot backfill unknown usage")
    func sessionAndDateBaselines() throws {
        let firstDay = try #require(self.date("2026-07-26T12:00:00Z"))
        let nextDay = try #require(self.date("2026-07-27T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        _ = engine.process(
            observations: [self.session("one", tokens: 10_000, at: firstDay)],
            at: firstDay,
            in: &state)
        let sameDay = engine.process(
            observations: [self.session("one", tokens: 60_000, at: firstDay)],
            at: firstDay,
            in: &state)
        let newSession = engine.process(
            observations: [self.session("two", tokens: 500_000, at: firstDay)],
            at: firstDay,
            in: &state)
        let newDate = engine.process(
            observations: [self.session("one", tokens: 160_000, at: nextDay)],
            at: nextDay,
            in: &state)

        #expect(sameDay.map(\.energy) == [2])
        #expect(newSession.isEmpty)
        #expect(newDate.isEmpty)
        #expect(state.conversionRemainderTokens == 0)
    }

    @Test("Decreasing counters never remove or duplicate energy")
    func decreasingCounter() throws {
        let now = try #require(self.date("2026-07-26T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()

        _ = engine.process(
            observations: [self.daily(.codex, tokens: 100_000, at: now)],
            at: now,
            in: &state)
        let decreased = engine.process(
            observations: [self.daily(.codex, tokens: 50_000, at: now)],
            at: now,
            in: &state)
        let recovered = engine.process(
            observations: [self.daily(.codex, tokens: 150_000, at: now)],
            at: now,
            in: &state)

        #expect(decreased.isEmpty)
        #expect(recovered.map(\.energy) == [2])
        #expect(state.dayCredits.first?.awardedEnergy == 6)
        #expect(state.conversionRemainderTokens == 0)
    }

    @Test("Large jumps require a matching second observation")
    func confirmsLargeJump() throws {
        let now = try #require(self.date("2026-07-26T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            maximumUnconfirmedDelta: 1_000,
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()
        let observation = self.daily(.codex, tokens: 100_000, at: now)

        let first = engine.process(observations: [observation], at: now, in: &state)
        let confirmed = engine.process(observations: [observation], at: now, in: &state)

        #expect(first.isEmpty)
        #expect(confirmed.map(\.energy) == [4])
    }

    @Test("Pending awards survive storage until marked applied")
    func pendingAwardPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "ledger.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = try #require(self.date("2026-07-26T12:00:00Z"))
        let engine = TokenGrowthLedgerEngine(
            formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000),
            calendar: self.calendar)
        var state = TokenGrowthLedgerState()
        let award = try #require(engine.process(
            observations: [self.daily(.codex, tokens: 100_000, at: now)],
            at: now,
            in: &state).first)
        let store = TokenGrowthLedgerStore(fileURL: file)

        try await store.save(state)
        var loaded = try await store.load()
        #expect(loaded.pendingAwards == [award])

        engine.markApplied(award.id, in: &loaded)
        try await store.save(loaded)
        let finalized = try await store.load()
        #expect(finalized.pendingAwards.isEmpty)
    }

    private func daily(
        _ providerID: ProviderID,
        tokens: Int64,
        at date: Date) -> GrowthUsageObservation
    {
        .daily(
            providerID: providerID,
            dateKey: GrowthLocalDate.key(for: date, calendar: self.calendar),
            totalTokens: tokens,
            observedAt: date)
    }

    private func session(
        _ id: String,
        tokens: Int64,
        at date: Date,
        providerID: ProviderID = .gemini) -> GrowthUsageObservation
    {
        GrowthUsageObservation(
            providerID: providerID,
            scope: .session,
            scopeID: id,
            totalTokens: tokens,
            observedAt: date)
    }

    private func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
