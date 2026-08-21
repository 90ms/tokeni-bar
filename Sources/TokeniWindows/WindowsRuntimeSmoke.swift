import Foundation
import TokeniApplication
import TokeniCore

/// Performs an offline check that is safe to run against an unpacked release.
///
/// This path deliberately constructs its own provider-neutral values. It does
/// not instantiate providers, inspect a user home directory, read credentials
/// or usage logs, or make network requests.
enum WindowsRuntimeSmoke {
    static let successMarker = "TOKENI_WINDOWS_SMOKE_OK"

    static func run(
        executableURL: URL,
        output: (String) -> Void = {
            FileHandle.standardOutput.write(Data(($0 + "\n").utf8))
        }) -> Int32
    {
        switch self.validate(executableURL: executableURL) {
        case let .success(details):
            output("\(self.successMarker) \(details)")
            return 0
        case let .failure(error):
            output("TOKENI_WINDOWS_SMOKE_FAILED \(error.description)")
            return 1
        }
    }

    static func validate(
        executableURL: URL) -> Result<String, WindowsRuntimeSmokeError>
    {
        guard let assetRoot = WindowsCompanionAssetCatalog.assetRoot(
            for: executableURL)
        else {
            return .failure(.companionAssetsUnavailable)
        }

        let manifestURL = assetRoot
            .appendingPathComponent("bytebot", isDirectory: true)
            .appendingPathComponent("manifest.json", isDirectory: false)
        guard let manifestData = try? Data(contentsOf: manifestURL),
              (try? JSONSerialization.jsonObject(with: manifestData)) != nil
        else {
            return .failure(.invalidCompanionManifest)
        }

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let descriptor = ProviderDescriptor(
            id: "smoke-provider",
            displayName: "Smoke Provider",
            shortName: "Smoke",
            systemImage: "circle",
            capabilities: ProviderCapabilities(supportsQuotaWindows: true))
        let snapshot = ProviderSnapshot(
            descriptor: descriptor,
            availability: .available,
            source: .localProtocol,
            quotaWindows: [
                QuotaWindow(
                    id: "smoke-window",
                    kind: .custom,
                    label: "Smoke",
                    usedPercent: 25),
            ],
            updatedAt: fixedDate)
        let state = UsageApplicationSessionState(
            applicationState: UsageApplicationState(
                snapshots: [snapshot],
                lastRefresh: fixedDate),
            providerDescriptors: [descriptor],
            enabledProviderIDs: [descriptor.id])
        let presentation = UsageApplicationPresentation(sessionState: state)
        let details = WindowsUsageDetailFormatter.text(
            for: presentation,
            now: fixedDate)

        guard presentation.minimumRemainingPercent == 75,
              details.contains("Smoke Provider"),
              details.contains("Smoke: 75% remaining")
        else {
            return .failure(.invalidPresentation)
        }

        return .success("assets=bytebot presentation=75")
    }
}

enum WindowsRuntimeSmokeError: Error, Equatable {
    case companionAssetsUnavailable
    case invalidCompanionManifest
    case invalidPresentation

    var description: String {
        switch self {
        case .companionAssetsUnavailable:
            "companion-assets-unavailable"
        case .invalidCompanionManifest:
            "invalid-companion-manifest"
        case .invalidPresentation:
            "invalid-presentation"
        }
    }
}
