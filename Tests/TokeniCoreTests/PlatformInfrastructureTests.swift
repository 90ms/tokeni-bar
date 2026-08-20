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
