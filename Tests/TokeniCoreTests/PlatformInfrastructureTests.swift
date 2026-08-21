@testable import TokeniCore
import Foundation
import Testing

struct PlatformInfrastructureTests {
    @Test
    func applicationSupportUsesInjectedPlatformDirectories() {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let directories = ApplicationDirectories(
            homeDirectory: root,
            applicationSupportDirectory: root.appending(path: "roaming"),
            cachesDirectory: root.appending(path: "cache"),
            localApplicationSupportDirectory: root.appending(path: "local"))

        let result = AppStoragePaths.applicationSupportDirectory(
            directories: directories)

        #expect(result == root.appending(
            path: "roaming/TokeniBar",
            directoryHint: .isDirectory))
    }

    @Test
    func defaultDirectoryProviderExposesAllRoots() {
        let directories = DefaultApplicationDirectoriesProvider().directories

        #expect(!directories.homeDirectory.path.isEmpty)
        #expect(!directories.applicationSupportDirectory.path.isEmpty)
        #expect(!directories.cachesDirectory.path.isEmpty)
        #expect(!directories.localApplicationSupportDirectory.path.isEmpty)

        #if !os(Windows)
        #expect(directories.localApplicationSupportDirectory
            == directories.applicationSupportDirectory)
        #endif
    }

    @Test
    func executableLocatorHandlesTheCurrentPlatformPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        #if os(Windows)
        let executable = root.appending(path: "tokeni-test.exe")
        #else
        let executable = root.appending(path: "tokeni-test")
        #endif
        try Data().write(to: executable)
        #if !os(Windows)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path)
        #endif

        let located = SystemExecutableLocator().locate(
            executableNames: ["tokeni-test"],
            pathEnvironment: root.path,
            homeDirectory: root)

        #expect(located == executable)
    }

    @Test
    func sqliteExecutableLocatorHandlesTheCurrentPlatformPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        #if os(Windows)
        let executable = root.appending(path: "sqlite3.exe")
        #else
        let executable = root.appending(path: "sqlite3")
        #endif
        try Data().write(to: executable)
        #if !os(Windows)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path)
        #endif

        let located = SystemSQLiteExecutableLocator().locate(
            pathEnvironment: root.path,
            homeDirectory: root)

        #expect(located == executable)
    }

    @Test
    func sqliteQueryRunnerKeepsTheReaderIndependentFromProcessExecution() async throws {
        let processRunner = RecordingProcessRunner(result: CommandResult(
            exitCode: 0,
            standardOutput: "[{\"value\":1}]",
            standardError: ""))
        let sqlite = ProcessSQLiteQueryRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/sqlite3"),
            runner: processRunner)

        let data = try await sqlite.queryJSON(
            databaseURL: URL(fileURLWithPath: "/tmp/usage.db"),
            sql: "SELECT value FROM usage;")
        let command = try #require(await processRunner.recordedCommand())

        #expect(data == Data("[{\"value\":1}]".utf8))
        #expect(command.arguments.contains("-readonly"))
        #expect(command.arguments.last == "SELECT value FROM usage;")
    }

    @Test
    func systemSQLiteQueryRunnerUsesInjectedExecutableAndProcessRunner() async throws {
        let executable = URL(fileURLWithPath: "/test/sqlite3")
        let processRunner = RecordingProcessRunner(result: CommandResult(
            exitCode: 0,
            standardOutput: "[{\"value\":1}]",
            standardError: ""))
        let sqlite = SystemSQLiteQueryRunner(
            executableURL: executable,
            runner: processRunner)

        let data = try await sqlite.queryJSON(
            databaseURL: URL(fileURLWithPath: "/tmp/usage.db"),
            sql: "SELECT value FROM usage;")
        let command = try #require(await processRunner.recordedCommand())

        #expect(data == Data("[{\"value\":1}]".utf8))
        #expect(command.executable == executable.path)
        #expect(command.arguments.contains("-readonly"))
        #expect(command.arguments.last == "SELECT value FROM usage;")
    }

    #if os(Windows)
    @Test
    func pinnedWindowsSQLitePerformsReadOnlyJSONRoundTrip() async throws {
        let environment = ProcessInfo.processInfo.environment
        let executablePath = try #require(
            environment["TOKENI_WINDOWS_SQLITE_EXECUTABLE"],
            "Windows CI must provide the pinned SQLite executable")
        let executable = URL(fileURLWithPath: executablePath)
        #expect(FileManager.default.fileExists(atPath: executable.path))

        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        let database = root.appending(path: "sqlite-roundtrip.db")
        let createResult = try await SystemProcessRunner().run(ProcessCommand(
            executable: executable.path,
            arguments: [
                "-batch",
                "-init", "NUL",
                database.path,
                "CREATE TABLE smoke(value INTEGER); INSERT INTO smoke VALUES(7);",
            ],
            timeout: 10))
        #expect(createResult.succeeded, "SQLite stderr: \(createResult.standardError)")
        let databaseBefore = try Data(contentsOf: database)

        let data = try await ProcessSQLiteQueryRunner(
            executableURL: executable).queryJSON(
                databaseURL: database,
                sql: "SELECT value FROM smoke;")
        let rows = try JSONDecoder().decode(
            [SQLiteRoundTripRow].self,
            from: data)
        let databaseAfter = try Data(contentsOf: database)

        #expect(rows == [SQLiteRoundTripRow(value: 7)])
        #expect(databaseAfter == databaseBefore)
    }

    @Test
    func systemProcessRunnerExecutesBatchFilesWithQuotedArguments() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "tokeni batch \(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        let batchFile = root.appending(path: "argument check.cmd")
        let script = """
            @echo off
            if not "%~1"=="argument with spaces" exit /b 41
            if not "%~2"=="" exit /b 42
            if not "%~3"=="slash/value" exit /b 43
            echo arguments-ok
            """
        try Data(script.replacingOccurrences(
            of: "\n",
            with: "\r\n").utf8).write(to: batchFile)
        let located = try #require(SystemExecutableLocator().locate(
            executableNames: ["argument check"],
            pathEnvironment: root.path,
            homeDirectory: root))

        let result = try await SystemProcessRunner().run(ProcessCommand(
            executable: located.path,
            arguments: ["argument with spaces", "", "slash/value"],
            timeout: 10))

        #expect(located == batchFile)
        #expect(
            result.exitCode == 0,
            "Batch stderr: \(result.standardError)")
        #expect(
            result.standardOutput.contains("arguments-ok"),
            "Batch stderr: \(result.standardError)")
    }

    @Test
    func systemProcessRunnerRejectsBatchCommandInjectionCharacters() async {
        do {
            _ = try await SystemProcessRunner().run(ProcessCommand(
                executable: "C:\\tokeni\\test.cmd",
                arguments: ["safe & echo injected"],
                timeout: 10))
            Issue.record("Expected unsafe batch arguments to be rejected")
        } catch let error as ProcessRunnerError {
            guard case let .launchFailed(message) = error else {
                Issue.record("Expected a launch failure, got \(error)")
                return
            }
            #expect(message.contains("unsupported command characters"))
        } catch {
            Issue.record("Expected ProcessRunnerError, got \(error)")
        }
    }
    #endif
}

private struct SQLiteRoundTripRow: Decodable, Equatable {
    let value: Int
}

private actor RecordingProcessRunner: ProcessRunning {
    private let result: CommandResult
    private var command: ProcessCommand?

    init(result: CommandResult) {
        self.result = result
    }

    func run(_ command: ProcessCommand) async throws -> CommandResult {
        self.command = command
        return self.result
    }

    func recordedCommand() -> ProcessCommand? {
        self.command
    }
}
