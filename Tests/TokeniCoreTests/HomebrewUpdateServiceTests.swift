import Foundation
import Testing
@testable import TokeniCore

@Suite("Homebrew update service")
struct HomebrewUpdateServiceTests {
    private let outdatedInfo = """
        [{
          "name": "tokeni-bar",
          "full_name": "90ms/tap/tokeni-bar",
          "versions": { "stable": "0.7.0" },
          "installed": [{ "version": "0.6.0" }]
        }]
        """

    @Test
    func parsesAvailableFormulaUpdate() throws {
        let info = try HomebrewUpdateService.parseFormulaInfo(self.outdatedInfo)

        #expect(info.installedVersion.description == "0.6.0")
        #expect(info.latestVersion.description == "0.7.0")
        #expect(info.isUpdateAvailable)
        #expect(info.isAvailable(for: SemanticVersion("0.7.0")!))
        #expect(!info.isAvailable(for: SemanticVersion("0.8.0")!))
    }

    @Test
    func installedReleaseCanBeRelinkedWithoutPackageUpgrade() throws {
        let value = """
            [{
              "versions": { "stable": "0.17.0" },
              "installed": [{ "version": "0.17.0" }]
            }]
            """
        let info = try HomebrewUpdateService.parseFormulaInfo(value)

        #expect(!info.isUpdateAvailable)
        #expect(info.isAvailable(for: SemanticVersion("0.17.0")!))
    }

    @Test
    func rejectsCaskOnlyInstallation() {
        let value = """
            [{
              "versions": { "stable": "0.7.0" },
              "installed": []
            }]
            """

        #expect(throws: HomebrewUpdateError.formulaNotInstalled) {
            try HomebrewUpdateService.parseFormulaInfo(value)
        }
    }

    @Test
    func commandsUseFixedFormulaAndAbsoluteExecutables() {
        let brew = "/opt/homebrew/bin/brew"

        #expect(HomebrewUpdateService.infoCommand(brew: brew).arguments == [
            "info", "--formula", "--json=v1", "90ms/tap/tokeni-bar",
        ])
        #expect(HomebrewUpdateService.upgradeCommand(brew: brew).arguments == [
            "upgrade", "--formula", "90ms/tap/tokeni-bar",
        ])
        #expect(HomebrewUpdateService.relinkCommand(brew: brew) == ProcessCommand(
            executable: "/opt/homebrew/bin/tokeni-bar",
            arguments: ["--install-app"],
            timeout: 30))
        #expect(HomebrewUpdateService.applicationPathCommand(brew: brew) == ProcessCommand(
            executable: "/opt/homebrew/bin/tokeni-bar",
            arguments: ["--print-app-path"],
            timeout: 30))

        let applicationPath = "/opt/homebrew/Cellar/tokeni-bar/0.20.3/libexec/Tokeni Bar.app"
        let restart = HomebrewUpdateService.restartCommand(
            applicationPath: applicationPath,
            processIdentifier: 42)
        #expect(restart.executable == "/bin/sh")
        #expect(Array(restart.arguments.dropFirst(2)) == [
            "tokeni-bar-restart", "42", applicationPath,
        ])
        #expect(restart.arguments[1].contains("kill -0 \"$old_pid\""))
        #expect(restart.arguments[1].contains("/usr/bin/open -n \"$application_path\""))
    }

    @Test
    func locatesOnlyKnownHomebrewPaths() {
        let result = HomebrewUpdateService.locateBrew {
            $0 == "/usr/local/bin/brew"
        }

        #expect(result == "/usr/local/bin/brew")
    }

    @Test
    func runsFormulaUpgradeAndRelinkInOrder() async throws {
        let runner = RecordingProcessRunner()
        let service = HomebrewUpdateService(runner: runner)

        try await service.upgradeFormula(brew: "/opt/homebrew/bin/brew")
        try await service.relinkApplication(brew: "/opt/homebrew/bin/brew")

        let commands = await runner.recordedCommands()
        #expect(commands.map(\.executable) == [
            "/opt/homebrew/bin/brew",
            "/opt/homebrew/bin/tokeni-bar",
        ])
        #expect(commands.map(\.arguments) == [
            ["upgrade", "--formula", "90ms/tap/tokeni-bar"],
            ["--install-app"],
        ])
    }

    @Test
    func readsCanonicalApplicationPathAfterRelinking() async throws {
        let applicationPath = "/opt/homebrew/Cellar/tokeni-bar/0.20.3/libexec/Tokeni Bar.app"
        let runner = RecordingProcessRunner(result: CommandResult(
            exitCode: 0,
            standardOutput: "\(applicationPath)\n",
            standardError: ""))
        let service = HomebrewUpdateService(runner: runner)

        #expect(try await service.applicationPath(brew: "/opt/homebrew/bin/brew") == applicationPath)
        let commands = await runner.recordedCommands()
        #expect(commands == [HomebrewUpdateService.applicationPathCommand(
            brew: "/opt/homebrew/bin/brew")])
    }

    @Test
    func reportsOperationOnFailure() async {
        let runner = RecordingProcessRunner(result: CommandResult(
            exitCode: 1,
            standardOutput: "",
            standardError: "network unavailable"))
        let service = HomebrewUpdateService(runner: runner)

        await #expect(throws: HomebrewUpdateError.commandFailed(
            operation: .refreshDefinitions,
            message: "network unavailable"))
        {
            try await service.refreshDefinitions(brew: "/opt/homebrew/bin/brew")
        }
    }
}

private actor RecordingProcessRunner: ProcessRunning {
    private var commands: [ProcessCommand] = []
    private let result: CommandResult

    init(result: CommandResult = CommandResult(
        exitCode: 0,
        standardOutput: "",
        standardError: ""))
    {
        self.result = result
    }

    func run(_ command: ProcessCommand) async throws -> CommandResult {
        self.commands.append(command)
        return self.result
    }

    func recordedCommands() -> [ProcessCommand] {
        self.commands
    }
}
