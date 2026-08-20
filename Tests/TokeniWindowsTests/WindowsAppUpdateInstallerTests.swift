import Foundation
import Testing
import TokeniCore
@testable import TokeniWindows

struct WindowsAppUpdateInstallerTests {
    @Test
    func defaultInstallerDoesNotExecuteAnUnspecifiedStrategy() async {
        let (update, _) = Self.update(
            currentVersion: "1.0.0",
            latestVersion: "1.1.0")

        await #expect(
            throws: WindowsAppUpdateInstallerError.installationStrategyUnavailable)
        {
            try await WindowsAppUpdateInstaller().install(update: update)
        }
    }

    @Test
    func reportsNoUpdateBeforeCheckingForAnInstallStrategy() async {
        let (update, _) = Self.update(
            currentVersion: "1.1.0",
            latestVersion: "1.1.0")

        await #expect(throws: WindowsAppUpdateInstallerError.noUpdateAvailable) {
            try await WindowsAppUpdateInstaller().install(update: update)
        }
    }

    @Test
    func injectedStrategyReceivesOnlyTheStableReleaseMetadata() async throws {
        let (update, expectedRelease) = Self.update(
            currentVersion: "1.0.0",
            latestVersion: "1.1.0")
        let recorder = ReleaseRecorder()
        let installer = WindowsAppUpdateInstaller { release in
            await recorder.record(release)
        }

        try await installer.install(update: update)

        #expect(await recorder.release == expectedRelease)
    }

    private static func update(
        currentVersion: String,
        latestVersion: String) -> (AppUpdateCheckResult, StableAppRelease)
    {
        let release = StableAppRelease(
            version: SemanticVersion(latestVersion)!,
            tagName: "v\(latestVersion)",
            name: "Tokeni Bar \(latestVersion)",
            pageURL: URL(
                string: "https://github.com/90ms/tokeni-bar/releases/tag/v\(latestVersion)")!,
            publishedAt: nil)
        return (
            AppUpdateCheckResult(
                currentVersion: SemanticVersion(currentVersion)!,
                latestRelease: release,
                source: .remote,
                checkedAt: Date(timeIntervalSince1970: 1_800_000_000),
                isStale: false),
            release)
    }
}

private actor ReleaseRecorder {
    private(set) var release: StableAppRelease?

    func record(_ release: StableAppRelease) {
        self.release = release
    }
}
