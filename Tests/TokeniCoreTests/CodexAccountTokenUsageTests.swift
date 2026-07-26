@testable import TokeniCore
import Foundation
import Testing

struct CodexAccountTokenUsageTests {
    @Test
    func decodesSanitizedAccountUsageFixture() throws {
        let file = try #require(Bundle.module.url(
            forResource: "codex-account-token-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let response = try JSONDecoder().decode(
            CodexAccountTokenUsageResponse.self,
            from: Data(contentsOf: file))

        #expect(response.summary.lifetimeTokens == 987_654_321)
        #expect(response.summary.peakDailyTokens == 7_654_321)
        #expect(response.dailyUsageBuckets?.map(\.startDate) == [
            "2026-07-19",
            "2026-07-20",
            "2026-07-21",
        ])
        #expect(response.dailyUsageBuckets?.map(\.tokens) == [
            1_200_000,
            3_400_000,
            5_600_000,
        ])
    }

    @Test
    func exchangesInitializeAndUsageRequestsWithAppServer() async throws {
        let fixture = try #require(Bundle.module.url(
            forResource: "codex-account-token-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let fixtureJSON = try String(contentsOf: fixture, encoding: .utf8)
            .replacingOccurrences(of: "\n", with: "")
        let executable = try self.makeExecutableScript(
            """
            #!/bin/sh
            IFS= read -r initialize_request
            printf '%s\\n' '{"id":1,"result":{"userAgent":"test","codexHome":"/tmp/test","platformFamily":"unix","platformOs":"macos"}}'
            IFS= read -r initialized_notification
            IFS= read -r usage_request
            printf '%s\\n' '{"id":2,"result":\(fixtureJSON)}'
            """)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }

        let client = CodexAccountTokenUsageClient(
            executableURL: executable,
            cache: CodexAccountTokenUsageCache(),
            timeout: 2)
        let result = try await client.fetch(accountID: "sanitized-account")

        #expect(result.response.summary.lifetimeTokens == 987_654_321)
        #expect(result.response.dailyUsageBuckets?.count == 3)
    }

    @Test
    func mapsUnsupportedMethodWithoutReturningServerMessage() async throws {
        let executable = try self.makeExecutableScript(
            """
            #!/bin/sh
            IFS= read -r initialize_request
            printf '%s\\n' '{"id":1,"result":{}}'
            IFS= read -r initialized_notification
            IFS= read -r usage_request
            printf '%s\\n' '{"id":2,"error":{"code":-32601,"message":"Method not found"}}'
            """)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }

        let client = CodexAccountTokenUsageClient(
            executableURL: executable,
            cache: CodexAccountTokenUsageCache(),
            timeout: 2)

        await #expect(throws: CodexAccountTokenUsageError.unsupported) {
            try await client.fetch()
        }
    }

    @Test
    func reportsMissingExplicitExecutable() async {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "codex")
        let client = CodexAccountTokenUsageClient(
            executableURL: missing,
            pathEnvironment: "",
            cache: CodexAccountTokenUsageCache())

        await #expect(throws: CodexAccountTokenUsageError.executableUnavailable) {
            try await client.fetch()
        }
    }

    @Test
    func cachesPerAccountAndSupportsInvalidation() async throws {
        let cache = CodexAccountTokenUsageCache()
        let response = CodexAccountTokenUsageResponse(
            summary: .init(
                lifetimeTokens: 42,
                peakDailyTokens: nil,
                longestRunningTurnSec: nil,
                currentStreakDays: nil,
                longestStreakDays: nil),
            dailyUsageBuckets: [])
        let fetchedAt = Date(timeIntervalSince1970: 2_000_000_000)

        await cache.store(response, accountID: "account-a", fetchedAt: fetchedAt)
        #expect(await cache.value(
            accountID: "account-a",
            maxAge: 300,
            now: fetchedAt.addingTimeInterval(299)) != nil)
        #expect(await cache.value(
            accountID: "account-b",
            maxAge: 300,
            now: fetchedAt.addingTimeInterval(299)) == nil)
        #expect(await cache.value(
            accountID: "account-a",
            maxAge: 300,
            now: fetchedAt.addingTimeInterval(300)) == nil)

        await cache.store(response, accountID: "account-a", fetchedAt: fetchedAt)
        await cache.invalidate()
        #expect(await cache.value(
            accountID: "account-a",
            maxAge: 300,
            now: fetchedAt) == nil)
    }

    private func makeExecutableScript(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appending(path: "codex")
        try contents.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path)
        return executable
    }
}
