import Foundation
// The executable entry point lives in a non-main.swift file so the @main
// declaration is accepted by SwiftPM on Windows as well as macOS.
import TokeniApplication
import TokeniCore
import WinSDK

@main
struct TokeniWindowsApp {
    static func main() async {
        if CommandLine.arguments.dropFirst().contains("--smoke-test") {
            let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            let exitCode = WindowsRuntimeSmoke.run(executableURL: executableURL)
            ExitProcess(UInt32(bitPattern: exitCode))
            return
        }

        // Claim the desktop instance before loading state or starting providers.
        let tray = WindowsTrayShell()
        guard tray.start() else { return }

        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let directories = DefaultApplicationDirectoriesProvider().directories
        let settings = JSONFileSettingsStore(
            fileURL: directories.localApplicationSupportDirectory.appending(
                path: "settings.json"))
        let providers = ProviderRegistry.defaultProviders(
            sqliteQueryRunner: WindowsSQLiteRuntime.queryRunner(
                for: executableURL))
        let session = UsageApplicationSession(
            providers: providers,
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))

        _ = try? await session.bootstrap()

        await session.start()

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

        let providerRefreshSignal = WindowsProviderRefreshSignal()
        let providerRefreshTask = Task { [session, providerRefreshSignal] in
            var handledRevision = 0
            while !Task.isCancelled {
                let revision = await providerRefreshSignal.revision()
                if revision <= handledRevision {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }

                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                let targetRevision = await providerRefreshSignal.revision()
                await session.refresh(forceProviderReload: true)
                handledRevision = targetRevision
            }
        }
        let providerToggleTask = Task {
            [session, tray, providerRefreshSignal] in
            var publishedSnapshot: WindowsProviderSelectionSnapshot?
            var isFinalPass = false
            while true {
                let knownPresentation = UsageApplicationPresentation(
                    sessionState: await session.state())
                let knownSnapshot = WindowsProviderSelectionFormatter.snapshot(
                    for: knownPresentation)
                let persisted = await WindowsProviderToggleScheduler.drain(
                    knownOptions: knownSnapshot.options,
                    take: { tray.takeProviderToggleRequest() },
                    persist: { change in
                        await session.setEnabled(
                            change.enabled,
                            for: change.providerID)
                    })
                if persisted {
                    await providerRefreshSignal.request()
                }
                if tray.takeRefreshRequest() {
                    await providerRefreshSignal.request()
                }

                // This task is the sole provider-control publisher. Capture
                // authoritative state only after every drained request has
                // finished persistence, so a matching native commit is a
                // causal acknowledgement. A click racing this capture/commit
                // remains pending natively when its final state mismatches.
                let authoritativePresentation = UsageApplicationPresentation(
                    sessionState: await session.state())
                let authoritativeSnapshot = WindowsProviderSelectionFormatter
                    .snapshot(for: authoritativePresentation)
                if WindowsProviderToggleScheduler.shouldPublish(
                    previous: publishedSnapshot,
                    current: authoritativeSnapshot,
                    persisted: persisted),
                   tray.updateProviderOptions(authoritativeSnapshot.options)
                {
                    publishedSnapshot = authoritativeSnapshot
                }

                // Cancellation may arrive after this pass already drained.
                // Run one explicit final pass after observing it; tray.run has
                // returned by then, so no later UI click can enter the queue.
                if Task.isCancelled {
                    if isFinalPass { return }
                    isFinalPass = true
                    continue
                }
                try? await Task.sleep(
                    for: WindowsProviderToggleScheduler.pollingInterval)
            }
        }

        let tooltipTask = Task {
            [session, tray, services, companionOverlay, companionGrowth, settings,
             initialCompanionVisible] in
            var companionVisible = initialCompanionVisible
            var serviceMessage: String?
            var lastDashboard: WindowsDashboardPresentation?
            var lastDetails: String?
            var lastCompanion: CompanionGameState?
            var lastFeedback: String?
            var didPublishCompanion = false
            while !Task.isCancelled {
                if let target = tray.takeGrowthTargetRequest() {
                    do {
                        try await companionGrowth.selectGrowthTarget(target)
                        serviceMessage = "Growth target saved."
                    } catch { serviceMessage = "Growth target could not be saved." }
                }
                if tray.takeHatchRequest() {
                    do {
                        try await companionGrowth.openNextEgg()
                        serviceMessage = "Your new companion is ready."
                    } catch { serviceMessage = "The egg could not be opened. Your saved state is unchanged." }
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
                let providerSnapshot = WindowsProviderSelectionFormatter
                    .snapshot(for: presentation)
                tray.updateTooltip(Self.tooltip(for: presentation))
                let dashboard = WindowsDashboardPresentation(presentation)
                if dashboard != lastDashboard {
                    tray.updateDashboard(dashboard)
                    lastDashboard = dashboard
                }
                var details = WindowsProviderSelectionFormatter.dashboardMessage(
                    for: presentation,
                    snapshot: providerSnapshot)
                    ?? WindowsUsageDetailFormatter.text(for: presentation)
                if let serviceMessage {
                    details += "\n\n\(serviceMessage)"
                }
                if details != lastDetails {
                    tray.updateDetails(details)
                    lastDetails = details
                }
                let currentCompanion = await companionGrowth.currentState()
                if !didPublishCompanion || currentCompanion != lastCompanion || serviceMessage != lastFeedback {
                    tray.updateCompanions(currentCompanion, feedback: serviceMessage)
                    lastCompanion = currentCompanion
                    lastFeedback = serviceMessage
                    didPublishCompanion = true
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        _ = tray.run()
        providerToggleTask.cancel()
        await providerToggleTask.value

        // Persisted final toggles are durable, but their best-effort refresh
        // is intentionally skipped during Quit. Provider implementations may
        // ignore cancellation, so normal teardown has a strict upper bound.
        providerRefreshTask.cancel()
        tooltipTask.cancel()
        await tooltipTask.value
        let sessionStopTask = Task { await session.stop() }
        let providerShutdownSignal = WindowsTaskCompletionSignal()
        Task {
            await providerRefreshTask.value
            await sessionStopTask.value
            providerShutdownSignal.finish()
        }
        let providerShutdownCompleted = await WindowsBoundedShutdown.wait(
            for: providerShutdownSignal,
            timeout: WindowsBoundedShutdown.providerDeadline)
        guard providerShutdownCompleted else {
            // Do not tear down host-owned windows while a cancellation-ignoring
            // provider can still return into session/history state. Ending the
            // process first makes the timeout policy bounded and race-free.
            ExitProcess(0)
            return
        }
        tray.stop()
        companionOverlay.stop()
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
