@testable import TokeniCore
import Foundation
import Testing

struct OpenCodeProviderTests {
    @Test
    func parsesSanitizedAggregateWithoutSessionContent() throws {
        let file = try #require(Bundle.module.url(
            forResource: "opencode-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let aggregate = try OpenCodeUsageParser.decode(Data(contentsOf: file))
        let usage = aggregate.tokenUsage

        #expect(aggregate.sessionCount == 3)
        #expect(abs(aggregate.costUSD - 0.0425) < 0.000_000_1)
        #expect(usage.inputTokens == 1200)
        #expect(usage.outputTokens == 300)
        #expect(usage.reasoningTokens == 50)
        #expect(usage.cachedInputTokens == 800)
        #expect(usage.cacheCreationInputTokens == 100)
        #expect(usage.totalTokens == 2450)
    }

    @Test
    func reportsUnavailableWithoutOpeningAnyCredentialFile() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)

        let snapshot = await OpenCodeUsageProvider(homeDirectory: temporaryHome).fetchUsage()

        #expect(snapshot.descriptor.id == .openCode)
        #expect(snapshot.availability == .unavailable)
        #expect(snapshot.tokenUsage == nil)
        #expect(snapshot.costEstimate == nil)
    }

    @Test
    func readsOnlyAggregateColumnsFromSanitizedDatabase() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let dataDirectory = temporaryHome.appending(
            path: ".local/share/opencode",
            directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let database = dataDirectory.appending(path: "opencode.db")
        try self.createSanitizedDatabase(at: database)

        let snapshot = await OpenCodeUsageProvider(homeDirectory: temporaryHome).fetchUsage()

        #expect(snapshot.availability == .available)
        #expect(snapshot.tokenUsage?.totalTokens == 2450)
        #expect(abs((snapshot.costEstimate?.amountUSD ?? 0) - 0.0425) < 0.000_000_1)
        #expect(snapshot.detail == "All-time local sessions · 3 sessions")
    }

    private func createSanitizedDatabase(at url: URL) throws {
        let schema = """
            CREATE TABLE session (
              cost REAL NOT NULL,
              tokens_input INTEGER NOT NULL,
              tokens_output INTEGER NOT NULL,
              tokens_reasoning INTEGER NOT NULL,
              tokens_cache_read INTEGER NOT NULL,
              tokens_cache_write INTEGER NOT NULL
            );
            INSERT INTO session VALUES (0.0200, 500, 100, 20, 300, 40);
            INSERT INTO session VALUES (0.0125, 400, 100, 20, 250, 30);
            INSERT INTO session VALUES (0.0100, 300, 100, 10, 250, 30);
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-batch", "-init", "/dev/null", url.path, schema]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw OpenCodeTestError.databaseCreationFailed
        }
    }
}

private enum OpenCodeTestError: Error {
    case databaseCreationFailed
}
