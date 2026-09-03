@testable import TokeniCore
import Foundation
import Testing

struct AntigravityProviderTests {
    @Test("Antigravity parses documented headless CLI quota groups")
    func parsesHeadlessCLIQuotaGroups() throws {
        let fixtureURL = try #require(Bundle.module.url(
            forResource: "antigravity-cli-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))

        let fixture = try Data(contentsOf: fixtureURL)
        var prefixedFixture = Data("startup notice\n".utf8)
        prefixedFixture.append(fixture)
        let windows = try AntigravityCLIUsageParser.parse(
            prefixedFixture)

        #expect(windows.map(\.id) == [
            "gemini-5h",
            "3p-weekly",
            "gemini-weekly",
        ])
        #expect(windows.map { Int($0.remainingPercent.rounded()) } == [84, 91, 72])
        #expect(windows[0].kind == .session)
        #expect(windows[0].durationMinutes == 300)
        #expect(windows.allSatisfy { $0.resetsAt != nil })
    }

    @Test("Antigravity remains locally available on a day without usage")
    func idleLocalStoreRemainsAvailable() async throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let databaseURL = home.appending(
            path: ".gemini/antigravity/conversations/previous.db",
            directoryHint: .notDirectory)
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data().write(to: databaseURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date.now.addingTimeInterval(-2 * 24 * 60 * 60)],
            ofItemAtPath: databaseURL.path)

        let provider = AntigravityUsageProvider(
            homeDirectory: home,
            roots: [databaseURL.deletingLastPathComponent()])
        let snapshot = await provider.fetchUsage()

        #expect(snapshot.availability == .available)
        #expect(snapshot.connectionState == .authorizationRequired)
        #expect(snapshot.tokenUsage == nil)
    }

    @Test("Antigravity gates quota checks to the safe CLI version")
    func gatesSafeCLIUsageVersion() {
        #expect(AntigravityCLIUsageParser.supportsSafeUsageCommand(
            "agy version 1.1.11"))
        #expect(AntigravityCLIUsageParser.supportsSafeUsageCommand(
            "Antigravity CLI 2.0.0"))
        #expect(!AntigravityCLIUsageParser.supportsSafeUsageCommand(
            "agy version 1.1.10"))
        #expect(!AntigravityCLIUsageParser.supportsSafeUsageCommand(
            "unknown"))
    }

    @Test("Antigravity CLI client uses the read-only usage command and cache")
    func cliClientUsesSafeCommandAndCache() async throws {
        let environment = try self.temporaryCLIEnvironment()
        defer { try? FileManager.default.removeItem(at: environment.home) }
        let runner = AntigravityCLIProcessRunner(
            usageResult: CommandResult(
                exitCode: 0,
                standardOutput: try self.cliFixtureString(),
                standardError: ""))
        let client = AntigravityCLIUsageClient(
            executableURL: environment.executable,
            homeDirectory: environment.home,
            processRunner: runner)

        _ = try await client.fetch()
        _ = try await client.fetch()
        _ = try await client.fetch(forceRefresh: true)
        let commands = await runner.recordedCommands()

        #expect(commands.count == 3)
        #expect(commands[0].arguments == ["--version"])
        #expect(Array(commands[1].arguments.prefix(4)) == [
            "-p", "/usage", "--output-format", "json",
        ])
        #expect(
            Array(commands[2].arguments.prefix(4))
                == Array(commands[1].arguments.prefix(4)))
    }

    @Test("Antigravity CLI client maps sign-in failures")
    func cliClientMapsSignInFailure() async throws {
        let environment = try self.temporaryCLIEnvironment()
        defer { try? FileManager.default.removeItem(at: environment.home) }
        let runner = AntigravityCLIProcessRunner(
            usageResult: CommandResult(
                exitCode: 1,
                standardOutput: "",
                standardError: "Authentication required. Sign in first."))
        let client = AntigravityCLIUsageClient(
            executableURL: environment.executable,
            homeDirectory: environment.home,
            processRunner: runner)

        await #expect(throws: AntigravityCLIUsageError.signInRequired) {
            _ = try await client.fetch()
        }
    }

    @Test("Antigravity CLI client preserves timeout failures")
    func cliClientMapsTimeout() async throws {
        let environment = try self.temporaryCLIEnvironment()
        defer { try? FileManager.default.removeItem(at: environment.home) }
        let client = AntigravityCLIUsageClient(
            executableURL: environment.executable,
            homeDirectory: environment.home,
            processRunner: AntigravityCLITimeoutRunner())

        await #expect(throws: AntigravityCLIUsageError.timedOut) {
            _ = try await client.fetch()
        }
    }

    @Test("Antigravity rejects malformed quota output")
    func rejectsMalformedQuotaOutput() {
        #expect(throws: AntigravityCLIUsageError.invalidResponse) {
            _ = try AntigravityCLIUsageParser.parse(Data("not-json".utf8))
        }
    }

    @Test("Antigravity keeps quotas but marks unreadable token data stale")
    func quotaSuccessWithDatabaseFailureIsPartial() async throws {
        let environment = try self.temporaryCLIEnvironment()
        defer { try? FileManager.default.removeItem(at: environment.home) }
        let databaseURL = environment.home.appending(
            path: ".gemini/antigravity/conversations/today.db")
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data().write(to: databaseURL)
        let processRunner = AntigravityCLIProcessRunner(
            usageResult: CommandResult(
                exitCode: 0,
                standardOutput: try self.cliFixtureString(),
                standardError: ""))
        let cliClient = AntigravityCLIUsageClient(
            executableURL: environment.executable,
            homeDirectory: environment.home,
            processRunner: processRunner)
        let provider = AntigravityUsageProvider(
            homeDirectory: environment.home,
            roots: [databaseURL.deletingLastPathComponent()],
            databaseReader: AntigravityDatabaseReader(
                queryRunner: RecordingSQLiteQueryRunner(
                    error: .executableUnavailable)),
            cliClient: cliClient)

        let snapshot = await provider.fetchUsage()

        #expect(snapshot.availability == .stale)
        #expect(snapshot.connectionState == .connected)
        #expect(snapshot.quotaWindows.count == 3)
        #expect(snapshot.tokenUsage == nil)
        #expect(snapshot.detail?.contains("could not be read safely") == true)
    }

    @Test("Antigravity database reader uses the injected SQLite boundary")
    func databaseReaderUsesInjectedQueryRunner() async throws {
        let databaseURL = try self.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let fixtureURL = try #require(Bundle.module.url(
            forResource: "antigravity-metadata",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let runner = RecordingSQLiteQueryRunner(
            response: try Data(contentsOf: fixtureURL))
        let reader = AntigravityDatabaseReader(queryRunner: runner)

        let rows = try await reader.readRows(from: databaseURL)
        let request = try #require(await runner.lastRequest())

        #expect(rows.count == 1)
        #expect(rows[0].index == 1)
        #expect(request.databaseURL == databaseURL)
        #expect(request.sql.contains("FROM gen_metadata"))
        #expect(request.sql.contains("hex(data) AS data_hex"))
    }

    @Test("Antigravity reports stale data when the injected SQLite reader fails")
    func failedSQLiteDataRemainsStale() async throws {
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

        #expect(snapshot.availability == .stale)
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

    private func cliFixtureString() throws -> String {
        let url = try #require(Bundle.module.url(
            forResource: "antigravity-cli-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func temporaryCLIEnvironment() throws -> (home: URL, executable: URL) {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let profile = home.appending(
            path: ".gemini/antigravity-cli",
            directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: profile,
            withIntermediateDirectories: true)
        let executable = home.appending(path: "agy")
        try Data().write(to: executable)
        #if !os(Windows)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path)
        #endif
        return (home, executable)
    }
}

private actor AntigravityCLIProcessRunner: ProcessRunning {
    private let usageResult: CommandResult
    private var commands: [ProcessCommand] = []

    init(usageResult: CommandResult) {
        self.usageResult = usageResult
    }

    func run(_ command: ProcessCommand) async throws -> CommandResult {
        self.commands.append(command)
        if command.arguments == ["--version"] {
            return CommandResult(
                exitCode: 0,
                standardOutput: "agy version 1.1.11",
                standardError: "")
        }
        return self.usageResult
    }

    func recordedCommands() -> [ProcessCommand] {
        self.commands
    }
}

private actor AntigravityCLITimeoutRunner: ProcessRunning {
    func run(_ command: ProcessCommand) async throws -> CommandResult {
        if command.arguments == ["--version"] {
            return CommandResult(
                exitCode: 0,
                standardOutput: "agy version 1.1.11",
                standardError: "")
        }
        throw ProcessRunnerError.timedOut(command.timeout ?? 0)
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
