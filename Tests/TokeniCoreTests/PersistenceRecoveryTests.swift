import Foundation
import Testing
@testable import TokeniCore

@Suite("Persistence recovery")
struct PersistenceRecoveryTests {
    @Test("The latest valid backup replaces a damaged companion state")
    func companionBackupRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "companion-state.json")
        let store = CompanionGameStateStore(fileURL: file)

        for generation in 1...4 {
            try await store.save(CompanionGameState(generationNumber: generation))
        }
        try Data("damaged".utf8).write(to: file, options: .atomic)

        let recovered = try await store.load()

        #expect(recovered.generationNumber == 3)
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
        #expect(files.contains {
            $0.lastPathComponent.hasPrefix("companion-state.corrupt-")
        })
    }

    @Test("Only the three most recent backups are retained")
    func backupRetention() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "rewards.json")
        let store = CompanionRewardStateStore(fileURL: file)

        for shards in 1...6 {
            try await store.save(CompanionRewardState(starShards: shards))
        }

        let backups = RecoverableFileStorage.backupURLs(for: file)
        #expect(backups.allSatisfy {
            FileManager.default.fileExists(atPath: $0.path)
        })
        #expect(!FileManager.default.fileExists(
            atPath: "\(file.path).backup-4"))
    }

    @Test("A damaged growth ledger never falls back to an empty ledger")
    func growthLedgerDoesNotReset() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let file = directory.appending(path: "growth-ledger.json")
        try Data("damaged".utf8).write(to: file)

        var loadFailed = false
        do {
            _ = try await TokenGrowthLedgerStore(fileURL: file).load()
        } catch {
            loadFailed = true
        }

        #expect(loadFailed)
        #expect(!FileManager.default.fileExists(atPath: file.path))

        loadFailed = false
        do {
            _ = try await TokenGrowthLedgerStore(fileURL: file).load()
        } catch {
            loadFailed = true
        }
        #expect(loadFailed)

        let store = TokenGrowthLedgerStore(fileURL: file)
        try await store.clear()
        #expect(try await store.load() == TokenGrowthLedgerState())
    }
}
