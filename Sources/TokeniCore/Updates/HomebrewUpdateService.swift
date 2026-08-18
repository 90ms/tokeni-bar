import Foundation

public struct HomebrewFormulaInfo: Sendable, Equatable {
    public let installedVersion: SemanticVersion
    public let latestVersion: SemanticVersion

    public init(installedVersion: SemanticVersion, latestVersion: SemanticVersion) {
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
    }

    public var isUpdateAvailable: Bool {
        self.installedVersion < self.latestVersion
    }

    public func isAvailable(for releaseVersion: SemanticVersion) -> Bool {
        self.latestVersion >= releaseVersion
    }
}

public enum HomebrewUpdateOperation: String, Sendable, Equatable {
    case readInstallation
    case refreshDefinitions
    case upgradeFormula
    case relinkApplication
    case restartApplication
}

public enum HomebrewUpdateError: Error, Sendable, Equatable {
    case homebrewNotFound
    case formulaNotInstalled
    case invalidResponse
    case commandFailed(operation: HomebrewUpdateOperation, message: String)
}

public struct HomebrewUpdateService: Sendable {
    public static let formulaName = "90ms/tap/tokeni-bar"

    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning = SystemProcessRunner()) {
        self.runner = runner
    }

    public static func candidateBrewPaths() -> [String] {
        [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]
    }

    public static func locateBrew(
        isExecutable: (String) -> Bool = {
            FileManager.default.isExecutableFile(atPath: $0)
        }) -> String?
    {
        self.candidateBrewPaths().first(where: isExecutable)
    }

    public static func infoCommand(brew: String) -> ProcessCommand {
        ProcessCommand(
            executable: brew,
            arguments: ["info", "--formula", "--json=v1", self.formulaName],
            timeout: 60)
    }

    public static func refreshCommand(brew: String) -> ProcessCommand {
        ProcessCommand(executable: brew, arguments: ["update"], timeout: 300)
    }

    public static func upgradeCommand(brew: String) -> ProcessCommand {
        ProcessCommand(
            executable: brew,
            arguments: ["upgrade", "--formula", self.formulaName],
            timeout: 1_800)
    }

    public static func launcherPath(brew: String) -> String {
        URL(fileURLWithPath: brew)
            .deletingLastPathComponent()
            .appendingPathComponent("tokeni-bar")
            .path
    }

    public static func relinkCommand(brew: String) -> ProcessCommand {
        ProcessCommand(
            executable: self.launcherPath(brew: brew),
            arguments: ["--install-app"],
            timeout: 30)
    }

    public static func applicationPathCommand(brew: String) -> ProcessCommand {
        ProcessCommand(
            executable: self.launcherPath(brew: brew),
            arguments: ["--print-app-path"],
            timeout: 30)
    }

    public static func restartCommand(
        applicationPath: String,
        processIdentifier: Int32) -> ProcessCommand
    {
        ProcessCommand(
            executable: "/bin/sh",
            arguments: [
                "-c",
                Self.delayedRestartScript,
                "tokeni-bar-restart",
                String(processIdentifier),
                applicationPath,
            ],
            timeout: 30)
    }

    public static func restartCommand(
        homeDirectory: String,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> ProcessCommand {
        let applicationPath = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Tokeni Bar.app", isDirectory: true)
            .path
        return self.restartCommand(
            applicationPath: applicationPath,
            processIdentifier: processIdentifier)
    }

    public static func parseFormulaInfo(_ value: String) throws -> HomebrewFormulaInfo {
        struct Response: Decodable {
            struct Versions: Decodable {
                let stable: String
            }

            struct Installation: Decodable {
                let version: String
            }

            let versions: Versions
            let installed: [Installation]
        }

        guard let data = value.data(using: .utf8),
              let response = try? JSONDecoder().decode([Response].self, from: data).first,
              let installedValue = response.installed.first?.version,
              let installedVersion = SemanticVersion(installedValue),
              let latestVersion = SemanticVersion(response.versions.stable)
        else {
            if let data = value.data(using: .utf8),
               let response = try? JSONDecoder().decode([Response].self, from: data).first,
               response.installed.isEmpty
            {
                throw HomebrewUpdateError.formulaNotInstalled
            }
            throw HomebrewUpdateError.invalidResponse
        }
        return HomebrewFormulaInfo(
            installedVersion: installedVersion,
            latestVersion: latestVersion)
    }

    public func readFormulaInfo(brew: String) async throws -> HomebrewFormulaInfo {
        let result = try await self.runner.run(Self.infoCommand(brew: brew))
        guard result.succeeded else {
            throw HomebrewUpdateError.commandFailed(
                operation: .readInstallation,
                message: Self.failureMessage(result))
        }
        return try Self.parseFormulaInfo(result.standardOutput)
    }

    public func refreshDefinitions(brew: String) async throws {
        try await self.run(
            Self.refreshCommand(brew: brew),
            operation: .refreshDefinitions)
    }

    public func upgradeFormula(brew: String) async throws {
        try await self.run(
            Self.upgradeCommand(brew: brew),
            operation: .upgradeFormula)
    }

    public func relinkApplication(brew: String) async throws {
        try await self.run(
            Self.relinkCommand(brew: brew),
            operation: .relinkApplication)
    }

    public func applicationPath(brew: String) async throws -> String {
        let result = try await self.runner.run(Self.applicationPathCommand(brew: brew))
        guard result.succeeded else {
            throw HomebrewUpdateError.commandFailed(
                operation: .relinkApplication,
                message: Self.failureMessage(result))
        }
        let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw HomebrewUpdateError.invalidResponse
        }
        return path
    }

    public func restartApplication(
        applicationPath: String,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) async throws {
        try await self.run(
            Self.restartCommand(
                applicationPath: applicationPath,
                processIdentifier: processIdentifier),
            operation: .restartApplication)
    }

    public func restartApplication(homeDirectory: String) async throws {
        let applicationPath = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Tokeni Bar.app", isDirectory: true)
            .path
        try await self.restartApplication(
            applicationPath: applicationPath,
            processIdentifier: ProcessInfo.processInfo.processIdentifier)
    }

    private static let delayedRestartScript = #"""
    old_pid="$1"
    application_path="$2"
    deadline=$(( $(date +%s) + 30 ))
    (
        while kill -0 "$old_pid" 2>/dev/null; do
            if [ "$(date +%s)" -ge "$deadline" ]; then
                break
            fi
            sleep 0.1
        done
        exec /usr/bin/open -n "$application_path"
    ) >/dev/null 2>&1 </dev/null &
    exit 0
    """#

    private func run(
        _ command: ProcessCommand,
        operation: HomebrewUpdateOperation) async throws
    {
        let result = try await self.runner.run(command)
        guard result.succeeded else {
            throw HomebrewUpdateError.commandFailed(
                operation: operation,
                message: Self.failureMessage(result))
        }
    }

    private static func failureMessage(_ result: CommandResult) -> String {
        let error = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = error.isEmpty ? output : error
        if message.isEmpty {
            return "Homebrew command failed."
        }
        return String(message.prefix(1_000))
    }
}
