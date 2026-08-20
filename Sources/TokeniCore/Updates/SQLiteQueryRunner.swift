import Foundation

public enum SQLiteQueryError: Error, Equatable, Sendable {
    case commandFailed(Int32)
    case invalidOutput
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
