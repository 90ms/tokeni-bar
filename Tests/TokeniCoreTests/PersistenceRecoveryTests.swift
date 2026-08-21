import Foundation
import Testing
@testable import TokeniCore

@Suite("Persistence recovery")
struct PersistenceRecoveryTests {
    @Test("Durable writes replace closed files without leaving temporary data")
    func durableReplacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "durable.json")

        for revision in 0..<20 {
            let data = Data("revision-\(revision)".utf8)
            try DurableFileWriter.write(data, to: file)
            #expect(try Data(contentsOf: file) == data)
        }

        let remainingFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
        #expect(remainingFiles.count == 1)
        #expect(remainingFiles.first?.lastPathComponent == "durable.json")
    }

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
        try DurableFileWriter.write(Data("damaged".utf8), to: file)

        let recovered = try await store.load()

        #expect(recovered.generationNumber == 3)
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
        #expect(files.contains {
            $0.lastPathComponent.hasPrefix("companion-state.corrupt-")
        })
    }

    @Test("A locked damaged primary can still read a valid backup")
    func backupFallbackWithoutPrimaryReplacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "state.json")
        let backup = try #require(
            RecoverableFileStorage.backupURLs(for: file).first)
        try DurableFileWriter.write(Data("damaged".utf8), to: file)
        try DurableFileWriter.write(Data("valid".utf8), to: backup)

        let recovered = try RecoverableFileStorage.load(
            from: file,
            quarantinePrimary: { _, _ in throw TestStorageError.locked },
            decode: { data in
                guard data == Data("valid".utf8) else {
                    throw TestStorageError.invalid
                }
                return data
            })

        #expect(recovered == Data("valid".utf8))
        #expect(try Data(contentsOf: file) == Data("damaged".utf8))
    }

    @Test("A failed clear never removes the primary before its backups")
    func clearFailureKeepsPrimary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "state.json")
        let backups = RecoverableFileStorage.backupURLs(for: file)
        try DurableFileWriter.write(Data("current".utf8), to: file)
        for backup in backups {
            try DurableFileWriter.write(Data("backup".utf8), to: backup)
        }

        do {
            try RecoverableFileStorage.removePrimaryAndBackups(
                for: file,
                removeItem: { url in
                    if url == backups[1] { throw TestStorageError.locked }
                    try FileManager.default.removeItem(at: url)
                })
            Issue.record("Expected backup removal to fail")
        } catch TestStorageError.locked {
            #expect(FileManager.default.fileExists(atPath: file.path))
            #expect(try Data(contentsOf: file) == Data("current".utf8))
        } catch {
            Issue.record("Unexpected clear error: \(error)")
        }
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

private enum TestStorageError: Error {
    case invalid
    case locked
}
