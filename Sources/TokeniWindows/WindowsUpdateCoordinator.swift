import Foundation
import TokeniCore
import TokeniWindowsNative

public enum WindowsUpdateCoordinator {
    public static func version(executableURL: URL) -> String? {
        struct Metadata: Decodable { let version: String }
        guard let data = try? Data(contentsOf: executableURL.deletingLastPathComponent().appending(path: "version.json")),
              let metadata = try? JSONDecoder().decode(Metadata.self, from: data),
              SemanticVersion(metadata.version) != nil else { return nil }
        return metadata.version
    }

    public static func run(executableURL: URL, tray: WindowsTrayShell) async {
        let version = self.version(executableURL: executableURL)
        let client = GitHubReleaseUpdateClient()
        var checked: AppUpdateCheckResult?
        var lastCheck = Date.distantPast
        var status = WindowsLocalization.text("Version \(version ?? "—") · Check for a new release.", "버전 \(version ?? "—") · 새 버전을 확인할 수 있습니다.")
        while !Task.isCancelled {
            let request = tokeni_windows_update_request()
            let automatic = tokeni_windows_update_automatic() != 0
            if let version, request == 1 || (automatic && Date.now.timeIntervalSince(lastCheck) > 6 * 60 * 60) {
                lastCheck = .now
                WindowsLocalization.text("Checking for updates…", "업데이트 확인 중…").withCString { tokeni_windows_update_status($0, 0) }
                do {
                    checked = try await client.check(currentVersion: version, force: true)
                    if let checked {
                        status = checked.isUpdateAvailable
                            ? WindowsLocalization.text("\(checked.latestRelease.version) available. Installation requires a signed Setup installation.", "\(checked.latestRelease.version) 업데이트 가능. 서명된 설치 버전에서 설치할 수 있습니다.")
                            : WindowsLocalization.text("Version \(version) is up to date.", "버전 \(version)이 최신입니다.")
                        if checked.isStale { status += WindowsLocalization.text(" · Offline cached result", " · 오프라인 캐시 결과") }
                    }
                } catch { status = WindowsLocalization.text("Update check failed. Try again when connected.", "업데이트를 확인하지 못했습니다. 연결 상태를 확인해 다시 시도하세요.") }
            }
            if request == 2, let checked, checked.isUpdateAvailable, !checked.isStale {
                WindowsLocalization.text("Downloading and verifying the update…", "업데이트를 다운로드하고 서명을 검증하는 중…").withCString { tokeni_windows_update_status($0, 0) }
                do {
                    try await WindowsAppUpdateInstaller.signedInstallation().install(update: checked)
                    tray.stop()
                    return
                } catch { status = WindowsLocalization.text("Update could not be installed. A signed per-user installation and matching signed release are required. Your current installation is unchanged.", "업데이트를 설치하지 못했습니다. 서명된 사용자 설치 버전과 같은 발행자의 서명된 릴리스가 필요합니다. 현재 설치는 유지됩니다.") }
            }
            status.withCString { tokeni_windows_update_status($0, checked?.isUpdateAvailable == true && checked?.isStale == false ? 1 : 0) }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
