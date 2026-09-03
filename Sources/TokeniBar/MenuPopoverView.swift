import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var caffeineController: CaffeineController
    @ObservedObject var mainNavigation: TokeniMainNavigation
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if self.store.companionEnabled {
                        self.companionSummary
                    }

                    self.providerSummaries

                    if let result = self.store.appUpdateResult,
                       result.isUpdateAvailable
                    {
                        self.updateBanner(
                            version: result.latestRelease.version.description,
                            destination: result.latestRelease.pageURL)
                    }

                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(minHeight: 170, idealHeight: 300, maxHeight: 460)

            Divider()

            self.footer
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(width: self.store.compactModeEnabled ? 320 : 360)
        .onAppear { self.store.start() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)

            Text(AppLocalization.string("app.title"))
                .font(.headline)

            Spacer()

            if let lastRefresh = self.store.lastRefresh {
                HStack(spacing: 3) {
                    Text(AppLocalization.string("usage.updated"))
                    Text(lastRefresh, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if self.store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task {
                        await self.store.refresh(forceProviderReload: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .tokeniIconButtonTarget()
                .help(AppLocalization.string("action.refresh"))
                .accessibilityLabel(AppLocalization.string("action.refresh"))
            }
        }
    }

    @ViewBuilder
    private var providerSummaries: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(
                    AppLocalization.string("menu.providers.title"),
                    systemImage: "chart.xyaxis.line")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    self.openMainWindow(destination: .usage)
                } label: {
                    Text(AppLocalization.string("menu.providers.details"))
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            if self.store.snapshots.isEmpty {
                Button {
                    self.openMainWindow(destination: .settings)
                } label: {
                    Label(
                        AppLocalization.string("empty.description"),
                        systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .background(
                    .quaternary.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(self.store.snapshots) { snapshot in
                    Button {
                        self.openMainWindow(destination: .usage)
                    } label: {
                        MenuProviderSummaryRow(
                            snapshot: snapshot,
                            isActive: self.store.activityAnimationsEnabled
                                && self.store.isActive(snapshot.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var companionSummary: some View {
        Button {
            self.openMainWindow(destination: .pets)
        } label: {
            HStack(spacing: 10) {
                ByteBotTransitionView(
                    speciesID: self.store.displayedCompanionAppearanceSpeciesID,
                    stage: self.store.displayedCompanionStage,
                    rarity: self.store.displayedCompanionRarity,
                    variantID: self.store.displayedCompanionVariantID,
                    behavior: self.store.companionBehavior,
                    mutationID: self.store.displayedCompanionMutationID,
                    cosmeticIDs: self.store.companionRewardState
                        .selectedCosmeticIDs,
                    dimension: 44,
                    animationsEnabled: self.store.companionAnimationsEnabled,
                    animationIntensity: self.store
                        .companionAnimationIntensity.motionScale,
                    interactionPulse: self.store.companionInteractionPulse,
                    growthPulse: self.store.isShowingArchivedCompanion
                        ? 0
                        : self.store.companionGrowthPulse)

                VStack(alignment: .leading, spacing: 3) {
                    Text(self.companionName)
                        .font(.callout.weight(.semibold))
                    Text(AppLocalization.format(
                        "menu.summary.companion",
                        self.store.displayedCompanionLevel,
                        AppLocalization.string(
                            "companion.stage.\(self.store.displayedCompanionStage.rawValue)")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .contentShape(Rectangle())
            .background(
                .quaternary.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var companionName: String {
        if let nickname = self.store.displayedCompanionNickname {
            return nickname
        }
        guard let speciesID = self.store.displayedCompanionSpeciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                self.openMainWindow(destination: .home)
            } label: {
                Label(
                    AppLocalization.string("main.open"),
                    systemImage: "macwindow")
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                self.caffeineController.toggle()
            } label: {
                Image(systemName: self.caffeineController.isEnabled
                    ? "cup.and.saucer.fill"
                    : "cup.and.saucer")
                    .foregroundStyle(
                        self.caffeineController.isEnabled
                            ? Color.orange
                            : Color.primary)
            }
            .buttonStyle(.borderless)
            .tokeniIconButtonTarget()
            .help(AppLocalization.string(
                self.caffeineController.isEnabled
                    ? "caffeine.disable"
                    : "caffeine.enable"))
            .accessibilityLabel(AppLocalization.string(
                self.caffeineController.isEnabled
                    ? "caffeine.disable"
                    : "caffeine.enable"))

            Button {
                self.openMainWindow(destination: .settings)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .tokeniIconButtonTarget()
            .help(AppLocalization.string("action.settings"))
            .accessibilityLabel(AppLocalization.string("action.settings"))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .tokeniIconButtonTarget()
            .help(AppLocalization.string("action.quit"))
            .accessibilityLabel(AppLocalization.string("action.quit"))
        }
        .controlSize(.small)
    }

    private func updateBanner(
        version: String,
        destination: URL) -> some View
    {
        Link(destination: destination) {
            HStack(spacing: 9) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.format(
                        "updates.menuAvailable",
                        version))
                        .font(.caption.weight(.semibold))
                    Text(AppLocalization.string("updates.menuDescription"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(9)
            .foregroundStyle(.primary)
            .background(
                Color.accentColor.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func activateApplication() {
        Task { @MainActor in
            await Task.yield()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func openMainWindow(destination: TokeniMainDestination) {
        self.mainNavigation.select(destination)
        self.openWindow(id: "tokeni-main")
        self.activateApplication()
    }
}

private struct MenuProviderSummaryRow: View {
    let snapshot: ProviderSnapshot
    let isActive: Bool

    private var representativeQuota: QuotaWindow? {
        self.snapshot.quotaWindows.min {
            if $0.remainingPercent != $1.remainingPercent {
                return $0.remainingPercent < $1.remainingPercent
            }
            return ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture)
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            ProviderIcon(descriptor: self.snapshot.descriptor, dimension: 14)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(self.snapshot.descriptor.displayName)
                        .font(.callout.weight(.semibold))
                    if self.isActive {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .accessibilityLabel(AppLocalization.string(
                                "activity.active"))
                    }
                }
                self.detail
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let quota = self.representativeQuota {
                Text(AppLocalization.format(
                    "menu.provider.remaining",
                    Int(quota.remainingPercent.rounded())))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(self.quotaColor(quota.remainingPercent))
            } else {
                self.availabilityIcon
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            .quaternary.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var detail: some View {
        if let quota = self.representativeQuota {
            HStack(spacing: 3) {
                Text(quota.label)
                if let reset = quota.resetsAt {
                    Text("·")
                    Text(AppLocalization.string("menu.provider.resets"))
                    Text(reset, style: .relative)
                }
            }
        } else if let tokenUsage = self.snapshot.tokenUsage {
            Text(AppLocalization.format(
                "menu.provider.tokens",
                tokenUsage.totalTokens.formatted(.number.notation(.compactName))))
        } else {
            Text(AppLocalization.string(
                "provider.status.\(self.snapshot.availability.rawValue)"))
        }
    }

    @ViewBuilder
    private var availabilityIcon: some View {
        switch self.snapshot.availability {
        case .loading:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .stale:
            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
        case .unavailable:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private func quotaColor(_ remaining: Double) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 30 { return .orange }
        return .primary
    }
}
