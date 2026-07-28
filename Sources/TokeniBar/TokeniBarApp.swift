import AppKit
import SwiftUI

@main
struct TokeniBarApp: App {
    @Environment(\.openSettings) private var openSettings
    @StateObject private var store = UsageStore()
    @StateObject private var companionOverlayController = CompanionOverlayController()

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
                .onAppear {
                    self.store.start()
                    self.companionOverlayController.connect(to: self.store)
                }
                .onChange(of: self.store.showsCompanionOverlay) { _, visible in
                    self.companionOverlayController.setVisible(visible)
                }
                .onChange(of: self.store.companionOverlaySize) { _, size in
                    self.companionOverlayController.setSize(size)
                }
                .onChange(of: self.store.companionOverlayPositionLocked) { _, locked in
                    self.companionOverlayController.setPositionLocked(locked)
                }
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
            MenuBarAppIcon(
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse,
                showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
        case .lowestRemaining:
            let remaining = self.store.menuBarRemainingPercent
            MenuBarAppIcon(
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse,
                showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
            if let remaining {
                Text(AppLocalization.format("app.menuRemaining", Int(remaining.rounded())))
            } else {
                Text(AppLocalization.string("app.menuName"))
            }
        case .monthlyCost:
            MenuBarAppIcon(
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse,
                showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
            if let cost = self.store.menuBarMonthlyCost {
                Text(AppLocalization.format("app.menuMonthlyCost", cost))
            } else {
                Text(AppLocalization.string("app.menuName"))
            }
        case .selectedProvider:
            let remaining = self.store.selectedMenuBarProviderRemainingPercent
            MenuBarAppIcon(
                isActive: self.store.activityAnimationsEnabled
                    && self.store.isActive(self.store.selectedMenuBarProviderID),
                animationPulse: self.store.activityAnimationPulse,
                showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
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
                MenuBarAppIcon(
                    isActive: self.store.showsActiveSession,
                    animationPulse: self.store.activityAnimationPulse,
                    showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
                Text(AppLocalization.string(
                    "companion.behavior.short.\(self.store.companionBehavior.rawValue)"))
            } else {
                MenuBarAppIcon(
                    isActive: self.store.showsActiveSession,
                    animationPulse: self.store.activityAnimationPulse,
                    showsCompanionBadge: false)
                Text(AppLocalization.string("app.menuName"))
            }
        }
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

private struct MenuBarAppIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool
    let animationPulse: Int
    let showsCompanionBadge: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 17, height: 17)
                .scaleEffect(
                    self.isActive && !self.reduceMotion && self.animationPulse.isMultiple(of: 2)
                        ? 0.9
                        : 1)
                .animation(
                    self.reduceMotion ? nil : .easeInOut(duration: 0.25),
                    value: self.animationPulse)

            if self.showsCompanionBadge {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .overlay {
                        Circle().stroke(.white.opacity(0.9), lineWidth: 1)
                    }
                    .offset(x: 2, y: -1)
                    .accessibilityLabel(AppLocalization.string(
                        "companion.action.ready"))
            }
        }
            .frame(width: 18, height: 18)
            .accessibilityLabel(self.accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let activity = self.isActive
            ? AppLocalization.string("activity.active")
            : AppLocalization.string("activity.idle")
        guard self.showsCompanionBadge else { return activity }
        return "\(activity), \(AppLocalization.string("companion.action.ready"))"
    }
}
