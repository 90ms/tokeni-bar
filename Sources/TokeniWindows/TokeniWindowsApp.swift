import Foundation
// The executable entry point lives in a non-main.swift file so the @main
// declaration is accepted by SwiftPM on Windows as well as macOS.
import TokeniApplication
import TokeniCore

@main
struct TokeniWindowsApp {
    static func main() async {
        let providers = ProviderRegistry.defaultProviders()
        let session = UsageApplicationSession(providers: providers)

        _ = try? await session.bootstrap()
        await session.start()

        let tray = WindowsTrayShell()
        guard tray.start() else {
            await session.stop()
            return
        }

        let tooltipTask = Task { [session, tray] in
            while !Task.isCancelled {
                if tray.takeRefreshRequest() {
                    await session.refresh(forceProviderReload: true)
                }
                let presentation = UsageApplicationPresentation(
                    sessionState: await session.state())
                tray.updateTooltip(Self.tooltip(for: presentation))
                tray.updateDetails(WindowsUsageDetailFormatter.text(
                    for: presentation))
                try? await Task.sleep(for: .seconds(5))
            }
        }

        _ = tray.run()
        tooltipTask.cancel()
        tray.stop()
        await session.stop()
    }

    private static func tooltip(
        for presentation: UsageApplicationPresentation) -> String
    {
        guard let remaining = presentation.minimumRemainingPercent else {
            return presentation.hasUnavailableData
                ? "Tokeni Bar · Usage unavailable"
                : "Tokeni Bar"
        }
        return "Tokeni Bar · \(Int(remaining.rounded()))% remaining"
    }
}
