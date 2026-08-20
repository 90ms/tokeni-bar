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

        let companionState = try? await CompanionGameStateStore().load()
        let companionOverlay = WindowsCompanionOverlay()
        companionOverlay.setAssetRoot(
            WindowsCompanionAssetCatalog.assetRoot(for: executableURL))
        companionOverlay.setState(Self.overlayState(for: companionState))
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
            [session, tray, services, companionOverlay, settings,
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

    private static func overlayState(
        for state: CompanionGameState?) -> WindowsCompanionOverlayState
    {
        guard let state else {
            return WindowsCompanionOverlayState(stage: 0, level: 0)
        }
        let stage: Int
        switch state.stage {
        case .egg: stage = 0
        case .hatchling: stage = 1
        case .junior: stage = 2
        case .adult: stage = 3
        }
        let speciesIndex = state.speciesID.flatMap { speciesID in
            CompanionSpeciesID.allCases.firstIndex(of: speciesID)
        } ?? 0
        let rarityRank = state.resolvedVariantID.map {
            CompanionVariantRegistry.definition(for: $0).assetRarity.rank
        } ?? state.rarity?.rank ?? 0
        return WindowsCompanionOverlayState(
            stage: stage,
            level: state.level,
            speciesIndex: speciesIndex,
            rarityRank: rarityRank)
    }
}
