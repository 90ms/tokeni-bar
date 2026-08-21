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

        let companionGrowth = WindowsCompanionGrowthCoordinator(session: session)
        var companionState = try? await companionGrowth.load()
        if companionState != nil {
            companionState = (try? await companionGrowth.applyPendingAwards())
                ?? companionState
        }
        let companionOverlay = WindowsCompanionOverlay()
        companionOverlay.setAssetRoot(
            WindowsCompanionAssetCatalog.assetRoot(for: executableURL))
        companionOverlay.setState(WindowsCompanionOverlayState(
            companionState: companionState))
        companionOverlay.setClickThrough(true)
        let companionOverlayStarted = companionOverlay.start(
            frame: WindowsCompanionOverlayFrame(
                x: 0,
                y: 0,
                width: 240,
                height: 220))
        let initialCompanionVisible = companionOverlayStarted
            && settings.bool(forKey: WindowsTrayServiceCoordinator.companionEnabledKey)
        if initialCompanionVisible {
            companionOverlay.show()
        }
        tray.setCompanionEnabled(initialCompanionVisible)

        let tooltipTask = Task {
            [session, tray, services, companionOverlay, companionGrowth, settings,
             initialCompanionVisible] in
            var companionVisible = initialCompanionVisible
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
                if tray.takeCompanionToggleRequest() {
                    companionVisible.toggle()
                    let didUpdate = companionVisible
                        ? companionOverlay.show()
                        : companionOverlay.hide()
                    if didUpdate {
                        settings.set(
                            companionVisible,
                            forKey: WindowsTrayServiceCoordinator.companionEnabledKey)
                        tray.setCompanionEnabled(companionVisible)
                        serviceMessage = companionVisible
                            ? "Companion overlay enabled."
                            : "Companion overlay disabled."
                    } else {
                        companionVisible.toggle()
                        serviceMessage =
                            "Companion overlay could not be changed."
                    }
                }
                if await companionGrowth.currentState() != nil {
                    let refreshedAt = await session.state()
                        .applicationState.lastRefresh
                    do {
                        let state = try await companionGrowth.synchronize(
                            afterRefreshAt: refreshedAt)
                        companionOverlay.setState(
                            WindowsCompanionOverlayState(companionState: state))
                    } catch {
                        // A persisted state remains safe to display. Failed
                        // awards stay pending and are retried on the next pass.
                        let state = await companionGrowth.currentState()
                        companionOverlay.setState(
                            WindowsCompanionOverlayState(companionState: state))
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
        companionOverlay.stop()
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
