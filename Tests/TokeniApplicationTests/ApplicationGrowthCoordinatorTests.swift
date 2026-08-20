@testable import TokeniApplication
import Foundation
import Testing
import TokeniCore

struct ApplicationGrowthCoordinatorTests {
    @Test
    func processesAndPersistsVerifiedGrowthObservations() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TokenGrowthLedgerStore(
            fileURL: directory.appending(path: "ledger.json"))
        let coordinator = TokenGrowthLedgerCoordinator(
            store: store,
            engine: TokenGrowthLedgerEngine(
                formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000)))
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        _ = try await coordinator.load()
        let update = try await coordinator.process(
            observations: [
                .daily(
                    providerID: .codex,
                    dateKey: GrowthLocalDate.key(for: date),
                    totalTokens: 100_000,
                    observedAt: date),
            ],
            at: date)

        #expect(update.awards.count == 1)
        #expect(update.state.pendingAwards == update.awards)
        let persisted = try await coordinator.load()
        #expect(persisted == update.state)
    }

    @Test
    func keepsAwardsUntilTheCompanionConsumerMarksThemApplied() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TokenGrowthLedgerStore(
            fileURL: directory.appending(path: "ledger.json"))
        let coordinator = TokenGrowthLedgerCoordinator(
            store: store,
            engine: TokenGrowthLedgerEngine(
                formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000)))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await coordinator.load()
        let update = try await coordinator.process(
            observations: [
                .daily(
                    providerID: .codex,
                    dateKey: GrowthLocalDate.key(for: date),
                    totalTokens: 100_000,
                    observedAt: date),
            ],
            at: date)
        let award = try #require(update.awards.first)

        let applied = try await coordinator.markApplied(award.id)

        #expect(applied.pendingAwards.isEmpty)
        let reloaded = try await coordinator.load()
        #expect(reloaded.pendingAwards.isEmpty)
    }
}
