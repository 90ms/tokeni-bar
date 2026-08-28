import AppKit
import TokeniCore
import SwiftUI

@main
struct TokeniBarApp: App {
    @StateObject private var store = UsageStore()
    @StateObject private var companionOverlayController = CompanionOverlayController()
    @StateObject private var caffeineController = CaffeineController()

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView(
                store: self.store,
                caffeineController: self.caffeineController)
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
                .onChange(
                    of: self.store.companionOverlayClickThroughEnabled
                ) { _, enabled in
                    self.companionOverlayController.setClickThroughEnabled(enabled)
                }
                .onChange(of: self.store.companionCelebration) { _, celebration in
                    if let celebration {
                        self.companionOverlayController.presentCelebration(celebration)
                    } else {
                        self.companionOverlayController.dismissCelebration()
                    }
                }
                .onChange(
                    of: self.store.companionOverlayPositionResetPulse
                ) { _, _ in
                    self.companionOverlayController.resetPosition(
                        size: self.store.companionOverlaySize)
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                store: self.store,
                caffeineController: self.caffeineController)
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
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch self.store.menuBarDisplayMode {
        case .iconOnly:
            MenuBarStatusIcon(
                systemName: "chart.bar.xaxis",
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse,
                showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
        case .lowestRemaining:
            let remaining = self.store.menuBarRemainingPercent
            MenuBarStatusIcon(
                systemName: self.menuBarIcon(for: remaining),
                isActive: self.store.showsActiveSession,
                animationPulse: self.store.activityAnimationPulse,
                showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
            if let remaining {
                Text(AppLocalization.format("app.menuRemaining", Int(remaining.rounded())))
            } else {
                Text(AppLocalization.string("app.menuName"))
            }
        case .monthlyCost:
            MenuBarStatusIcon(
                systemName: "dollarsign.circle",
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
            if let provider = self.store.selectedMenuBarProvider {
                HStack(spacing: 3) {
                    MenuBarStatusIcon(
                        systemName: self.menuBarIcon(for: remaining),
                        provider: provider,
                        isActive: self.store.activityAnimationsEnabled
                            && self.store.isActive(
                                self.store.selectedMenuBarProviderID),
                        animationPulse: self.store.activityAnimationPulse,
                        showsCompanionBadge: self.store
                            .hasReadyCompanionGrowthAction)
                    if let remaining {
                        Text(AppLocalization.format(
                            "app.menuProviderPercent",
                            Int(remaining.rounded())))
                    } else {
                        Text(AppLocalization.string(
                            "app.menuProviderPercentUnavailable"))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(self.selectedProviderAccessibilityLabel(
                    provider: provider,
                    remaining: remaining))
                .help(self.selectedProviderAccessibilityLabel(
                    provider: provider,
                    remaining: remaining))
            } else {
                MenuBarStatusIcon(
                    systemName: "chart.bar.xaxis",
                    isActive: false,
                    animationPulse: self.store.activityAnimationPulse,
                    showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
                Text(AppLocalization.string("app.menuName"))
            }
        case .tokeni:
            if self.store.companionEnabled {
                MenuBarStatusIcon(
                    systemName: "bolt.horizontal.circle",
                    isActive: self.store.showsActiveSession,
                    animationPulse: self.store.activityAnimationPulse,
                    showsCompanionBadge: self.store.hasReadyCompanionGrowthAction)
                Text(AppLocalization.string(
                    "companion.behavior.short.\(self.store.companionBehavior.rawValue)"))
            } else {
                MenuBarStatusIcon(
                    systemName: "chart.bar.xaxis",
                    isActive: self.store.showsActiveSession,
                    animationPulse: self.store.activityAnimationPulse,
                    showsCompanionBadge: false)
                Text(AppLocalization.string("app.menuName"))
            }
        }
    }

    private func menuBarIcon(for remaining: Double?) -> String {
        guard let remaining else { return "chart.bar.xaxis" }
        return remaining < 10 ? "exclamationmark.triangle.fill" : "chart.bar.xaxis"
    }

    private func selectedProviderAccessibilityLabel(
        provider: ProviderDescriptor,
        remaining: Double?) -> String
    {
        guard let remaining else {
            return AppLocalization.format(
                "app.menuProviderUnavailable",
                provider.shortName)
        }
        return AppLocalization.format(
            "app.menuProviderRemaining",
            provider.shortName,
            Int(remaining.rounded()))
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

private struct MenuBarStatusIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemName: String
    var provider: ProviderDescriptor? = nil
    let isActive: Bool
    let animationPulse: Int
    let showsCompanionBadge: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let provider = self.provider {
                    ProviderIcon(descriptor: provider)
                        .symbolEffect(
                            .pulse,
                            value: self.isActive && !self.reduceMotion
                                ? self.animationPulse
                                : 0)
                } else if self.isActive, !self.reduceMotion {
                    Image(systemName: "waveform")
                        .symbolEffect(.pulse, value: self.animationPulse)
                } else {
                    if self.isActive {
                        Image(systemName: "waveform")
                    } else {
                        Image(systemName: self.systemName)
                    }
                }
            }
            .frame(width: 15, height: 15)

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
            .frame(width: 17, height: 17)
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
