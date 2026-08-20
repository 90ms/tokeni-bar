import TokeniCore

/// The Windows deployment contract is intentionally kept separate from the
/// update-checking contract. Until PR20 defines a signed package and its
/// installation mechanism, the default installer must not download or execute
/// anything.
public enum WindowsAppUpdateInstallerError: Error, Equatable, Sendable {
    /// No signed package and installation strategy have been supplied yet.
    case installationStrategyUnavailable

    /// The supplied release is not newer than the running application.
    case noUpdateAvailable
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
