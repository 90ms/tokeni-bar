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

        let directories = DefaultApplicationDirectoriesProvider().directories
        let settings = JSONFileSettingsStore(
            fileURL: directories.localApplicationSupportDirectory.appending(
                path: "settings.json"))
        let executableURL = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
        let services = WindowsTrayServiceCoordinator(
            executableURL: executableURL,
            settings: settings)
        tray.setLaunchAtLoginEnabled(
            await services.isLaunchAtLoginEnabled())

        let tooltipTask = Task { [session, tray] in
            var serviceMessage: String?
            while !Task.isCancelled {
                if tray.takeRefreshRequest() {
                    await session.refresh(forceProviderReload: true)
                }
                if tray.takeLaunchAtLoginRequest() {
                    do {
                        let enabled = try await services.toggleLaunchAtLogin()
                        tray.setLaunchAtLoginEnabled(enabled)
                        serviceMessage = enabled
                            ? "Start with Windows enabled."
                            : "Start with Windows disabled."
                    } catch {
                        serviceMessage =
                            "Start with Windows could not be changed."
                    }
                }
                if tray.takeTestNotificationRequest() {
                    do {
                        try await services.sendTestNotification()
                        serviceMessage = "Test notification sent."
                    } catch {
                        serviceMessage = "Test notification could not be sent."
                    }
                }
                let presentation = UsageApplicationPresentation(
                    sessionState: await session.state())
                tray.updateTooltip(Self.tooltip(for: presentation))
                var details = WindowsUsageDetailFormatter.text(
                    for: presentation)
                if let serviceMessage {
                    details += "\n\n\(serviceMessage)"
                }
                tray.updateDetails(details)
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
