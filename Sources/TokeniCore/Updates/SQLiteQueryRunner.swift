import Foundation

public enum SQLiteQueryError: Error, Equatable, Sendable {
    case executableUnavailable
    case commandFailed(Int32)
    case invalidOutput
}

/// Locates the read-only SQLite command without exposing platform-specific
/// executable suffixes or PATH separators to provider code.
public struct SystemSQLiteExecutableLocator: Sendable {
    public init() {}

    public func locate(
        pathEnvironment: String? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL?
    {
        let pathEnvironment = pathEnvironment
            ?? PlatformEnvironment.pathValue(from: ProcessInfo.processInfo.environment)
        if let located = SystemExecutableLocator().locate(
            executableNames: ["sqlite3"],
            pathEnvironment: pathEnvironment,
            homeDirectory: homeDirectory)
        {
            return located
        }

        #if os(Windows)
        return nil
        #else
        return [
            "/usr/bin/sqlite3",
            "/opt/homebrew/bin/sqlite3",
            "/usr/local/bin/sqlite3",
        ].map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
        #endif
    }
}

/// A platform-neutral SQLite query service backed by the existing process
/// boundary. Providers can inject a runner and executable for deterministic
/// tests or a platform-specific application adapter.
public struct SystemSQLiteQueryRunner: ReadOnlySQLiteQuerying {
    private let executableURL: URL?
    private let pathEnvironment: String?
    private let homeDirectory: URL
    private let runner: any ProcessRunning

    public init(
        executableURL: URL? = nil,
        pathEnvironment: String? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        runner: any ProcessRunning = SystemProcessRunner())
    {
        self.executableURL = executableURL
        self.pathEnvironment = pathEnvironment
        self.homeDirectory = homeDirectory
        self.runner = runner
    }

    public func queryJSON(databaseURL: URL, sql: String) async throws -> Data {
        guard let executableURL = self.executableURL
                ?? SystemSQLiteExecutableLocator().locate(
                    pathEnvironment: self.pathEnvironment,
                    homeDirectory: self.homeDirectory)
        else {
            throw SQLiteQueryError.executableUnavailable
        }
        return try await ProcessSQLiteQueryRunner(
            executableURL: executableURL,
            runner: self.runner)
            .queryJSON(databaseURL: databaseURL, sql: sql)
    }
}

public struct ProcessSQLiteQueryRunner: ReadOnlySQLiteQuerying {
    private let executableURL: URL
    private let runner: any ProcessRunning

    public init(
        executableURL: URL,
        runner: any ProcessRunning = SystemProcessRunner())
    {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func queryJSON(databaseURL: URL, sql: String) async throws -> Data {
        #if os(Windows)
        let nullDevice = "NUL"
        #else
        let nullDevice = "/dev/null"
        #endif
        let result = try await self.runner.run(ProcessCommand(
            executable: self.executableURL.path,
            arguments: [
                "-batch",
                "-init", nullDevice,
                "-readonly",
                "-json",
                databaseURL.path,
                sql,
            ],
            timeout: 30))
        guard result.succeeded else {
            throw SQLiteQueryError.commandFailed(result.exitCode)
        }
        guard let data = result.standardOutput.data(using: .utf8) else {
            throw SQLiteQueryError.invalidOutput
        }
        return data
    }
}
