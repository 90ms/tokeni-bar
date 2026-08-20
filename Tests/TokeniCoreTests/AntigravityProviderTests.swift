@testable import TokeniCore
import Foundation
import Testing

struct AntigravityProviderTests {
    @Test("Antigravity database reader uses the injected SQLite boundary")
    func databaseReaderUsesInjectedQueryRunner() async throws {
        let databaseURL = try self.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let fixtureURL = try #require(Bundle.module.url(
            forResource: "antigravity-metadata",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let runner = RecordingSQLiteQueryRunner(
            response: Data(contentsOf: fixtureURL))
        let reader = AntigravityDatabaseReader(queryRunner: runner)

        let rows = try await reader.readRows(from: databaseURL)
        let request = try #require(await runner.lastRequest())

        #expect(rows.count == 1)
        #expect(rows[0].index == 1)
        #expect(request.databaseURL == databaseURL)
        #expect(request.sql.contains("FROM gen_metadata"))
        #expect(request.sql.contains("hex(data) AS data_hex"))
    }

    @Test("Antigravity stays unavailable when the injected SQLite reader fails")
    func missingSQLiteDataRemainsUnavailable() async throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let databaseURL = home.appending(
            path: ".gemini/antigravity/conversations/today.db",
            directoryHint: .notDirectory)
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data().write(to: databaseURL)

        let runner = RecordingSQLiteQueryRunner(
            error: SQLiteQueryError.executableUnavailable)
        let provider = AntigravityUsageProvider(
            homeDirectory: home,
            roots: [databaseURL.deletingLastPathComponent()],
            sqliteQueryRunner: runner)

        let snapshot = await provider.fetchUsage()

        #expect(snapshot.availability == .unavailable)
        #expect(await runner.requestCount() == 1)
    }

    private func temporaryDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let databaseURL = directory.appending(
            path: "conversation.db",
            directoryHint: .notDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        try Data().write(to: databaseURL)
        return databaseURL
    }
}

private actor RecordingSQLiteQueryRunner: ReadOnlySQLiteQuerying {
    struct Request: Sendable {
        let databaseURL: URL
        let sql: String
    }

    private let response: Data?
    private let error: SQLiteQueryError?
    private var requests: [Request] = []

    init(response: Data) {
        self.response = response
        self.error = nil
    }

    init(error: SQLiteQueryError) {
        self.response = nil
        self.error = error
    }

    func queryJSON(databaseURL: URL, sql: String) async throws -> Data {
        self.requests.append(Request(databaseURL: databaseURL, sql: sql))
        if let error = self.error {
            throw error
        }
        return self.response ?? Data()
    }

    func lastRequest() -> Request? {
        self.requests.last
    }

    func requestCount() -> Int {
        self.requests.count
    }
}
