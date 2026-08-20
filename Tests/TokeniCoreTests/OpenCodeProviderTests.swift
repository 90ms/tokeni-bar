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
    func readsOnlyAggregateColumnsUsingInjectedSQLiteReader() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let dataDirectory = temporaryHome.appending(
            path: ".local/share/opencode",
            directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let database = dataDirectory.appending(path: "opencode.db")
        try Data("portable test database placeholder".utf8).write(to: database)
        let queryRunner = RecordingSQLiteQueryRunner(response: try self.fixtureData())

        let snapshot = await OpenCodeUsageProvider(
            homeDirectory: temporaryHome,
            queryRunner: queryRunner).fetchUsage()
        let recordedSQL = await queryRunner.recordedSQL()

        #expect(snapshot.availability == .available)
        #expect(snapshot.tokenUsage?.totalTokens == 2450)
        #expect(snapshot.growthUsageObservation?.scope == .lifetime)
        #expect(snapshot.growthUsageObservation?.scopeID == "opencode.db")
        #expect(snapshot.growthUsageObservation?.totalTokens == 2450)
        #expect(abs((snapshot.costEstimate?.amountUSD ?? 0) - 0.0425) < 0.000_000_1)
        #expect(snapshot.detail == "All-time local sessions · 3 sessions")
        #expect(recordedSQL?.contains("COUNT(*) AS session_count") == true)
        #expect(recordedSQL?.contains("SUM(tokens_cache_write)") == true)
        #expect(recordedSQL?.contains("FROM session") == true)
    }

    @Test
    func reportsFailedWhenInjectedSQLiteReaderFails() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let dataDirectory = temporaryHome.appending(
            path: ".local/share/opencode",
            directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try Data("portable test database placeholder".utf8).write(
            to: dataDirectory.appending(path: "opencode.db"))

        let snapshot = await OpenCodeUsageProvider(
            homeDirectory: temporaryHome,
            queryRunner: FailingSQLiteQueryRunner()).fetchUsage()

        #expect(snapshot.availability == .failed)
        #expect(snapshot.tokenUsage == nil)
        #expect(snapshot.costEstimate == nil)
    }

    private func fixtureData() throws -> Data {
        let file = try #require(Bundle.module.url(
            forResource: "opencode-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        return try Data(contentsOf: file)
    }
}

private actor RecordingSQLiteQueryRunner: ReadOnlySQLiteQuerying {
    private let response: Data
    private var sql: String?

    init(response: Data) {
        self.response = response
    }

    func queryJSON(databaseURL: URL, sql: String) async throws -> Data {
        self.sql = sql
        return self.response
    }

    func recordedSQL() -> String? {
        self.sql
    }
}

private struct FailingSQLiteQueryRunner: ReadOnlySQLiteQuerying {
    func queryJSON(databaseURL: URL, sql: String) async throws -> Data {
        throw SQLiteQueryError.commandFailed(1)
    }
}
