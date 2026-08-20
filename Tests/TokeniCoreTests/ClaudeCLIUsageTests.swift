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
        let session = try #require(first.response.quotaWindows.first)
        let weekly = try #require(first.response.quotaWindows.dropFirst().first)
        let modelWeekly = try #require(first.response.quotaWindows.dropFirst(2).first)
        #expect(session.resetsAt != nil)
        #expect(weekly.resetsAt != nil)
        #expect(modelWeekly.resetsAt == nil)
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
    func parsesTimeOnlyAndWeekdayResetTimes() throws {
        let fixture = try #require(Bundle.module.url(
            forResource: "claude-cli-usage-reset-formats",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let data = try Data(contentsOf: fixture)
        let timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try #require(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 8,
            day: 19,
            hour: 12,
            minute: 0)))

        let response = try ClaudeCLIUsageParser.parse(
            data,
            now: now,
            timeZone: timeZone)
        let session = try #require(response.quotaWindows.first)
        let weekly = try #require(response.quotaWindows.dropFirst().first)
        let sessionReset = try #require(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 8,
            day: 19,
            hour: 15,
            minute: 45)))
        let weeklyReset = try #require(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 8,
            day: 24,
            hour: 0,
            minute: 0)))
        let datedFixture = try #require(Bundle.module.url(
            forResource: "claude-cli-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let datedResponse = try ClaudeCLIUsageParser.parse(
            Data(contentsOf: datedFixture),
            now: now,
            timeZone: timeZone)
        let datedSession = try #require(datedResponse.quotaWindows.first)
        let datedSessionReset = try #require(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 8,
            day: 19,
            hour: 13,
            minute: 40)))

        #expect(session.usedPercent == 12)
        #expect(weekly.usedPercent == 34)
        #expect(session.resetsAt == sessionReset)
        #expect(weekly.resetsAt == weeklyReset)
        #expect(datedSession.resetsAt == datedSessionReset)
    }

    @Test
    func backsOffRepeatedCLIFailuresUntilTheRetryWindowExpires() async {
        let cache = ClaudeCLIUsageCache()
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        await cache.storeFailure(.timedOut, retryAfter: 90, now: now)
        #expect(await cache.failure(now: now.addingTimeInterval(89)) == .timedOut)
        #expect(await cache.failure(now: now.addingTimeInterval(90)) == nil)
    }

    @Test
    func usesInjectedConfigDirectoryForClaudeProjectHistory() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let configDirectory = root.appending(path: "claude-config", directoryHint: .isDirectory)
        let projectsDirectory = configDirectory.appending(
            path: "projects/example",
            directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: projectsDirectory,
            withIntermediateDirectories: true)
        let session = projectsDirectory.appending(path: "session.jsonl")
        try Data().write(to: session)

        let provider = ClaudeUsageProvider(
            homeDirectory: root.appending(path: "home", directoryHint: .isDirectory),
            configDirectory: configDirectory)

        #expect(provider.latestActivityDate(since: .distantPast) != nil)
    }

    @Test
    func configDirectoryEnvironmentAndExplicitInjectionAreDeterministic() throws {
        let home = URL(fileURLWithPath: "/tmp/claude-test-home", isDirectory: true)
        let environmentDirectory = URL(
            fileURLWithPath: "/tmp/claude-config-from-environment",
            isDirectory: true)
        let explicitDirectory = URL(
            fileURLWithPath: "/tmp/claude-config-injected",
            isDirectory: true)

        #expect(ClaudeUsageProvider.resolvedConfigDirectory(
            homeDirectory: home,
            explicitDirectory: nil,
            environment: ["CLAUDE_CONFIG_DIR": environmentDirectory.path])
            == environmentDirectory)
        #expect(ClaudeUsageProvider.resolvedConfigDirectory(
            homeDirectory: home,
            explicitDirectory: explicitDirectory,
            environment: ["CLAUDE_CONFIG_DIR": environmentDirectory.path])
            == explicitDirectory)
        #expect(ClaudeUsageProvider.resolvedConfigDirectory(
            homeDirectory: home,
            explicitDirectory: nil,
            environment: [:])
            == home.appending(path: ".claude", directoryHint: .isDirectory))
    }

    #if os(Windows)
    @Test
    func locatesNativeClaudeBinaryInUserProfileLocalBin() throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let executable = home.appending(
            path: ".local/bin/claude.exe",
            directoryHint: .notDirectory)
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data().write(to: executable)

        let locator = ClaudeExecutableLocator(
            pathEnvironment: nil,
            homeDirectory: home)

        #expect(locator.resolve() == executable)
    }

    @Test
    func locatesNativeClaudeBinaryFromWindowsPathEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let pathDirectory = root.appending(path: "path-entry", directoryHint: .isDirectory)
        let executable = pathDirectory.appending(path: "claude.exe")
        try FileManager.default.createDirectory(
            at: pathDirectory,
            withIntermediateDirectories: true)
        try Data().write(to: executable)
        let missingDirectory = root.appending(path: "missing", directoryHint: .isDirectory)

        let locator = ClaudeExecutableLocator(
            pathEnvironment: "\(missingDirectory.path);\(pathDirectory.path)",
            homeDirectory: root.appending(path: "home", directoryHint: .isDirectory))

        #expect(locator.resolve() == executable)
    }
    #endif

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
