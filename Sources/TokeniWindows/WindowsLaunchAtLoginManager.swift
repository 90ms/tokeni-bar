import Foundation
import TokeniCore
import TokeniWindowsNative

public enum WindowsLaunchAtLoginError: Error, Equatable, Sendable {
    case invalidApplicationName
    case invalidExecutablePath
    case unsupportedPlatform
    case registryOperationFailed
}

/// Registers the current executable in the current user's Run key.
///
/// The adapter intentionally accepts the registry value name and executable
/// path from its caller. It never writes to a machine-wide key and does not
/// expose any WinSDK types to Swift callers.
public struct WindowsLaunchAtLoginManager: LaunchAtLoginManaging, Sendable {
    public let applicationName: String
    public let executablePath: String

    public init(applicationName: String, executablePath: String) {
        self.applicationName = applicationName
        self.executablePath = executablePath
    }

    public init(applicationName: String, executableURL: URL) {
        self.init(
            applicationName: applicationName,
            executablePath: executableURL.path)
    }

    public func isEnabled() async -> Bool {
        guard Self.isValidApplicationName(self.applicationName) else {
            return false
        }

        #if os(Windows)
        return self.applicationName.withCString { applicationName in
            tokeni_windows_launch_at_login_is_enabled(applicationName) != 0
        }
        #else
        return false
        #endif
    }

    public func setEnabled(_ enabled: Bool) async throws {
        guard Self.isValidApplicationName(self.applicationName) else {
            throw WindowsLaunchAtLoginError.invalidApplicationName
        }
        if enabled && !Self.isValidExecutablePath(self.executablePath) {
            throw WindowsLaunchAtLoginError.invalidExecutablePath
        }

        #if os(Windows)
        let result = self.applicationName.withCString { applicationName in
            self.executablePath.withCString { executablePath in
                tokeni_windows_launch_at_login_set_enabled(
                    applicationName,
                    executablePath,
                    enabled ? 1 : 0)
            }
        }
        guard result != 0 else {
            throw WindowsLaunchAtLoginError.registryOperationFailed
        }
        #else
        throw WindowsLaunchAtLoginError.unsupportedPlatform
        #endif
    }

    private static func isValidApplicationName(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("\0")
    }

    private static func isValidExecutablePath(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("\0") && !value.contains("\"")
    }
}
