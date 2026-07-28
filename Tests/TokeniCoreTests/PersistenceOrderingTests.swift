import Foundation
import Testing
@testable import TokeniCore

@Suite("Persistence ordering")
struct PersistenceOrderingTests {
    @Test("Older companion saves cannot overwrite a newer revision")
    func companionOrdering() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionGameStateStore(
            fileURL: directory.appending(path: "companion.json"))

        try await store.save(
            CompanionGameState(generationNumber: 2),
            revision: 2)
        try await store.save(
            CompanionGameState(generationNumber: 1),
            revision: 1)

        #expect(try await store.load().generationNumber == 2)
    }

    @Test("Older reward saves cannot overwrite a newer revision")
    func rewardOrdering() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionRewardStateStore(
            fileURL: directory.appending(path: "rewards.json"))

        try await store.save(
            CompanionRewardState(starShards: 20),
            revision: 2)
        try await store.save(
            CompanionRewardState(starShards: 10),
            revision: 1)

        #expect(try await store.load().starShards == 20)
    }

    @Test("Older ledger saves cannot overwrite a newer revision")
    func ledgerOrdering() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TokenGrowthLedgerStore(
            fileURL: directory.appending(path: "ledger.json"))
        let newer = TokenGrowthLedgerState(dayCredits: [
            GrowthDayCredit(
                dateKey: "2026-07-28",
                aggregateTokens: 100,
                targetEnergy: 1,
                awardedEnergy: 1),
        ])

        try await store.save(newer, revision: 2)
        try await store.save(TokenGrowthLedgerState(), revision: 1)

        #expect(try await store.load().dayCredits == newer.dayCredits)
    }
}
