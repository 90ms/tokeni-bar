@testable import TokeniCore
import Foundation
import Testing

struct ClaudeCLIUsageTests {
    @Test
    func invokesClaudeCLIUsageCommandAndCachesTheResult() async throws {
        let fixture = try #require(Bundle.module.url(
            forResource: "claude-cli-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let fixtureJSON = try String(contentsOf: fixture, encoding: .utf8)
            .replacingOccurrences(of: "\n", with: "")
        let executable = try self.makeExecutableScript(
            """
            #!/bin/sh
            if [ "$1" != "--print" ] || [ "$2" != "--no-session-persistence" ]; then
              exit 7
            fi
            printf '%s\n' '\(fixtureJSON)'
            """)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }

        let client = ClaudeCLIUsageClient(
            executableURL: executable,
            pathEnvironment: "",
            cache: ClaudeCLIUsageCache(),
            timeout: 2)
        let first = try await client.fetch()
        let second = try await client.fetch()

        #expect(first.response == second.response)
        #expect(first.response.quotaWindows.map(\.usedPercent) == [12, 34, 25])
    }

    @Test
    func launchesClaudeWithSiblingRuntimeOnAnAppStylePath() async throws {
        let fixture = try #require(Bundle.module.url(
            forResource: "claude-cli-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let fixtureJSON = try String(contentsOf: fixture, encoding: .utf8)
            .replacingOccurrences(of: "\n", with: "")
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        _ = try self.makeExecutableScript(
            """
            #!/bin/sh
            exec /bin/sh "$@"
            """,
            named: "tokeni-test-runtime",
            in: directory)
        let executable = try self.makeExecutableScript(
            """
            #!/usr/bin/env tokeni-test-runtime
            printf '%s\n' '\(fixtureJSON)'
            """,
            in: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let client = ClaudeCLIUsageClient(
            executableURL: executable,
            pathEnvironment: "",
            cache: ClaudeCLIUsageCache(),
            timeout: 2)
        let result = try await client.fetch()

        #expect(result.response.quotaWindows.map(\.usedPercent) == [12, 34, 25])
    }

    @Test
    func backsOffRepeatedCLIFailuresUntilTheRetryWindowExpires() async {
        let cache = ClaudeCLIUsageCache()
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        await cache.storeFailure(.timedOut, retryAfter: 90, now: now)
        #expect(await cache.failure(now: now.addingTimeInterval(89)) == .timedOut)
        #expect(await cache.failure(now: now.addingTimeInterval(90)) == nil)
    }

    private func makeExecutableScript(
        _ contents: String,
        named: String = "claude",
        in directory: URL? = nil) throws -> URL
    {
        let directory = directory ?? FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let executable = directory.appending(path: named)
        try contents.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path)
        return executable
    }
}
