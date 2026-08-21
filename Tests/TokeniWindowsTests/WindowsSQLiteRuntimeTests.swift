import Foundation
import Testing
import TokeniCore
@testable import TokeniWindows

struct WindowsSQLiteRuntimeTests {
    @Test
    func resolvesOnlyTheExecutableRelativeBundledTool() {
        let executable = URL(fileURLWithPath:
            "C:\\Portable Apps\\Tokeni Bar\\TokeniWindows.exe")

        let sqlite = WindowsSQLiteRuntime.executableURL(for: executable)
        let expected = executable.deletingLastPathComponent()
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent("sqlite3.exe", isDirectory: false)

        #expect(sqlite == expected)
    }

    @Test
    func queryRunnerUsesBundledPathInsteadOfPATH() async throws {
        let application = URL(fileURLWithPath:
            "C:\\Portable Apps\\Tokeni Bar\\TokeniWindows.exe")
        let processRunner = RecordingWindowsSQLiteProcessRunner()
        let sqlite = WindowsSQLiteRuntime.queryRunner(
            for: application,
            processRunner: processRunner)

        _ = try await sqlite.queryJSON(
            databaseURL: URL(fileURLWithPath: "C:\\Fixtures\\usage.db"),
            sql: "SELECT 1 AS value;")
        let command = try #require(await processRunner.command())
        let expected = application.deletingLastPathComponent()
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent("sqlite3.exe", isDirectory: false)

        #expect(command.executable == expected.path)
        #expect(command.arguments.contains("-readonly"))
        #expect(command.arguments.contains("-json"))
    }
}

private actor RecordingWindowsSQLiteProcessRunner: ProcessRunning {
    private var recordedCommand: ProcessCommand?

    func run(_ command: ProcessCommand) async throws -> CommandResult {
        self.recordedCommand = command
        return CommandResult(
            exitCode: 0,
            standardOutput: "[{\"value\":1}]",
            standardError: "")
    }

    func command() -> ProcessCommand? {
        self.recordedCommand
    }
}
