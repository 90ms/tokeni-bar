import Foundation
import TokeniCore

/// Resolves the SQLite CLI shipped next to the portable Windows executable.
/// Windows production code always supplies this exact path to the process
/// boundary and never falls back to a user or CI runner PATH entry.
enum WindowsSQLiteRuntime {
    static func executableURL(for applicationExecutableURL: URL) -> URL {
        applicationExecutableURL.deletingLastPathComponent()
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent("sqlite3.exe", isDirectory: false)
    }

    static func queryRunner(
        for applicationExecutableURL: URL,
        processRunner: any ProcessRunning = SystemProcessRunner())
        -> SystemSQLiteQueryRunner
    {
        SystemSQLiteQueryRunner(
            executableURL: self.executableURL(for: applicationExecutableURL),
            runner: processRunner)
    }
}
