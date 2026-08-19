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

    private func makeExecutableScript(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appending(path: "claude")
        try contents.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path)
        return executable
    }
}
