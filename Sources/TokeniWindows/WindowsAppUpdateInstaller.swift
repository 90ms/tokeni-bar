import TokeniCore
import TokeniWindowsNative

/// Deployment remains separate from update discovery. The desktop explicitly
/// selects signedInstallation(); the parameterless initializer stays inert for
/// callers that have not chosen an installation strategy.
public enum WindowsAppUpdateInstallerError: Error, Equatable, Sendable {
    /// No signed package and installation strategy have been supplied yet.
    case installationStrategyUnavailable

    /// The supplied release is not newer than the running application.
    case noUpdateAvailable
    case signatureOrInstallationFailed
}

/// Installs a release through an explicitly supplied Windows deployment
/// strategy.
///
/// `WindowsAppUpdateInstaller()` is deliberately inert: its `install` method
/// reports `installationStrategyUnavailable` until a package strategy is
/// provided. The injected handler receives only the checked release metadata;
/// it never receives network response content, credentials, or application
/// state.
public struct WindowsAppUpdateInstaller: AppUpdateInstalling, Sendable {
    public static func signedInstallation() -> Self {
        Self { release in
            let prepared = await Task.detached {
                release.version.description.withCString { version in
                    release.tagName.withCString { tag in tokeni_windows_update_prepare(version, tag) != 0 }
                }
            }.value
            guard prepared else { throw WindowsAppUpdateInstallerError.signatureOrInstallationFailed }
        }
    }
    public typealias InstallHandler = @Sendable (StableAppRelease) async throws -> Void

    private let installHandler: InstallHandler?

    /// Creates the safe, unsupported-by-default Windows installer.
    public init() {
        self.installHandler = nil
    }

    /// Creates an installer backed by an explicit deployment strategy.
    ///
    /// The strategy is injected so the signed package format and installation
    /// command can be added later without changing the shared contract. The
    /// handler receives only `update.latestRelease`.
    public init(installHandler: @escaping InstallHandler) {
        self.installHandler = installHandler
    }

    public func install(update: AppUpdateCheckResult) async throws {
        guard update.isUpdateAvailable else {
            throw WindowsAppUpdateInstallerError.noUpdateAvailable
        }
        guard let installHandler = self.installHandler else {
            throw WindowsAppUpdateInstallerError.installationStrategyUnavailable
        }

        try await installHandler(update.latestRelease)
    }
}
