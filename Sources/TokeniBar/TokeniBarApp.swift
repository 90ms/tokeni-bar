import AppKit
import SwiftUI

@main
struct TokeniBarApp: App {
    @Environment(\.openSettings) private var openSettings
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                HStack {
                    Text(AppLocalization.string("app.title"))
                        .font(.headline)
                    Spacer()
                    if self.store.isRefreshing {
                        ProgressView().controlSize(.small)
                    }
                    Button {
                        Task { await self.store.refresh(forceProviderReload: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help(AppLocalization.string("action.refresh"))
                }
                .padding(.bottom, 8)

                if self.store.companionEnabled {
                    CompanionCard(
                        store: self.store,
                        compact: self.store.compactModeEnabled)
                    Divider()
                        .padding(.vertical, 8)
                }

                if self.store.snapshots.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.string("empty.title"),
                        systemImage: "chart.bar",
                        description: Text(AppLocalization.string("empty.description")))
                    .frame(height: 130)
                } else {
                    ForEach(Array(self.store.snapshots.enumerated()), id: \.element.id) { index, snapshot in
                        if index > 0 { Divider() }
                        ProviderRow(
                            snapshot: snapshot,
                            costCurrency: self.store.costDisplayCurrency,
                            exchangeRate: self.store.exchangeRateQuote,
                            compact: self.store.compactModeEnabled,
                            isActive: self.store.activityAnimationsEnabled
                                && self.store.isActive(snapshot.id))
                    }
                }

                if let result = self.store.appUpdateResult, result.isUpdateAvailable {
                    Divider()
                        .padding(.vertical, 6)
                    Link(destination: result.latestRelease.pageURL) {
                        Label(
                            AppLocalization.format(
                                "updates.menuAvailable",
                                result.latestRelease.version.description),
                            systemImage: "arrow.down.circle")
                    }
                    .font(.caption)
                }

                Divider()
                    .padding(.vertical, 8)
                HStack {
                    Button(AppLocalization.string("action.settings")) {
                        self.openSettings()
                        Task { @MainActor in
                            await Task.yield()
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                    }
                    Spacer()
                    Button(AppLocalization.string("action.quit")) { NSApplication.shared.terminate(nil) }
                }
            }
            .padding(12)
            .frame(width: self.store.compactModeEnabled ? 300 : 340)
            .onAppear { self.store.start() }
        } label: {
            self.menuBarLabel
                .onAppear { self.store.start() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: self.store)
                .background(WindowFocusView())
        }

        Window(AppLocalization.string("history.title"), id: "usage-history") {
            HistoryView(store: self.store)
        }
        .defaultSize(width: 720, height: 460)

        Window(AppLocalization.string("diagnostics.title"), id: "provider-diagnostics") {
            DiagnosticsView(store: self.store)
        }
        .defaultSize(width: 680, height: 480)

        Window(AppLocalization.string("companion.collection.window"), id: "companion-collection") {
            CompanionCollectionView(store: self.store)
                .background(WindowFocusView())
        }
        .defaultSize(width: 620, height: 720)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch self.store.menuBarDisplayMode {
        case .iconOnly:
            ActivityStatusIcon(
                systemName: "chart.bar.fill",
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse)
        case .lowestRemaining:
            let remaining = self.store.menuBarRemainingPercent
            ActivityStatusIcon(
                systemName: self.menuBarIcon(for: remaining),
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse)
            if let remaining {
                Text(AppLocalization.format("app.menuRemaining", Int(remaining.rounded())))
            } else {
                Text(AppLocalization.string("app.menuName"))
            }
        case .monthlyCost:
            ActivityStatusIcon(
                systemName: "dollarsign.circle.fill",
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse)
            if let cost = self.store.menuBarMonthlyCost {
                Text(AppLocalization.format("app.menuMonthlyCost", cost))
            } else {
                Text(AppLocalization.string("app.menuName"))
            }
        case .selectedProvider:
            let remaining = self.store.selectedMenuBarProviderRemainingPercent
            ActivityStatusIcon(
                systemName: self.menuBarIcon(for: remaining),
                isActive: self.store.activityAnimationsEnabled
                    && self.store.isActive(self.store.selectedMenuBarProviderID),
                animationPulse: self.store.activityAnimationPulse)
            if let provider = self.store.selectedMenuBarProvider, let remaining {
                Text(AppLocalization.format(
                    "app.menuProviderRemaining",
                    provider.shortName,
                    Int(remaining.rounded())))
            } else if let provider = self.store.selectedMenuBarProvider {
                Text(AppLocalization.format("app.menuProviderUnavailable", provider.shortName))
            } else {
                Text(AppLocalization.string("app.menuName"))
            }
        case .tokeni:
            if self.store.companionEnabled {
                ByteBotSpriteView(
                    speciesID: self.store.companionState.speciesID,
                    stage: self.store.companionStage,
                    rarity: self.store.companionDisplayRarity,
                    behavior: self.store.companionBehavior,
                    dimension: 18,
                    // Continuously invalidating a MenuBarExtra label can block the
                    // status item while AppKit is opening its window.
                    animationsEnabled: false)
                Text(AppLocalization.string(
                    "companion.behavior.short.\(self.store.companionBehavior.rawValue)"))
            } else {
                ActivityStatusIcon(
                    systemName: "chart.bar.fill",
                    isActive: self.store.showsActiveSession,
                    animationPulse: self.store.activityAnimationPulse)
                Text(AppLocalization.string("app.menuName"))
            }
        }
    }

    private func menuBarIcon(for remaining: Double?) -> String {
        guard let remaining else { return "chart.bar.fill" }
        return remaining < 10 ? "exclamationmark.triangle.fill" : "chart.bar.fill"
    }
}

private struct WindowFocusView: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowFocusNSView {
        WindowFocusNSView()
    }

    func updateNSView(_ nsView: WindowFocusNSView, context: Context) {}
}

private final class WindowFocusNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

private struct ActivityStatusIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemName: String
    let isActive: Bool
    let animationPulse: Int

    var body: some View {
        Group {
            if self.isActive, !self.reduceMotion {
                Image(systemName: "waveform")
                    .symbolEffect(.pulse, value: self.animationPulse)
            } else {
                Image(systemName: self.isActive ? "waveform" : self.systemName)
            }
        }
            .frame(width: 14, height: 14)
            .accessibilityLabel(self.isActive
                ? AppLocalization.string("activity.active")
                : AppLocalization.string("activity.idle"))
    }
}
