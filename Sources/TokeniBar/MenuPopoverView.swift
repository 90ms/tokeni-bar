import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var showsCompanionDetails = false

    var body: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if self.store.companionMigrationQuote != nil {
                        CompanionMigrationCard(
                            store: self.store,
                            showsReceiptDismissButton: true)
                    }

                    if !self.store.snapshots.isEmpty {
                        Text(AppLocalization.string("settings.tab.usage"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    self.providerContent

                    if let result = self.store.appUpdateResult,
                       result.isUpdateAvailable
                    {
                        self.updateBanner(
                            version: result.latestRelease.version.description,
                            destination: result.latestRelease.pageURL)
                    }

                    if self.store.companionMigrationQuote == nil,
                       self.store.companionMigrationReceiptNoticeVisible
                    {
                        CompanionMigrationCard(
                            store: self.store,
                            showsReceiptDismissButton: true)
                    }

                    if self.store.companionEnabled {
                        self.companionSummary
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(
                minHeight: self.contentMinimumHeight,
                idealHeight: self.contentIdealHeight,
                maxHeight: 560)

            Divider()

            self.footer
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(width: self.store.compactModeEnabled ? 320 : 360)
        .onAppear { self.store.start() }
    }

    private var contentMinimumHeight: CGFloat {
        if self.store.companionEnabled {
            return self.store.compactModeEnabled ? 300 : 340
        }
        return self.store.compactModeEnabled ? 180 : 220
    }

    private var contentIdealHeight: CGFloat {
        self.store.companionEnabled ? 500 : 360
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
    private var providerContent: some View {
        if self.store.snapshots.isEmpty {
            ContentUnavailableView {
                Label(
                    AppLocalization.string("empty.title"),
                    systemImage: "chart.bar")
            } description: {
                Text(AppLocalization.string("empty.description"))
            } actions: {
                Button(AppLocalization.string("action.settings")) {
                    self.openSettings()
                    self.activateApplication()
                }
            }
                .frame(height: 130)
        } else {
            VStack(spacing: 8) {
                ForEach(self.store.snapshots) { snapshot in
                    ProviderRow(
                        snapshot: snapshot,
                        costCurrency: self.store.costDisplayCurrency,
                        exchangeRate: self.store.exchangeRateQuote,
                        compact: self.store.compactModeEnabled,
                        isActive: self.store.activityAnimationsEnabled
                            && self.store.isActive(snapshot.id))
                }
            }
        }
    }

    private var companionSummary: some View {
        DisclosureGroup(isExpanded: self.$showsCompanionDetails) {
            CompanionCard(
                store: self.store,
                compact: self.store.compactModeEnabled)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 9) {
                ByteBotTransitionView(
                    speciesID: self.store.displayedCompanionSpeciesID,
                    stage: self.store.displayedCompanionStage,
                    rarity: self.store.displayedCompanionRarity,
                    behavior: .idle,
                    cosmeticIDs: self.store.companionRewardState
                        .selectedCosmeticIDs,
                    dimension: 36,
                    animationsEnabled: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.companionSummaryName)
                        .font(.caption.weight(.semibold))
                    Text(AppLocalization.string(
                        "companion.stage."
                            + self.store.displayedCompanionStage.rawValue))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if self.store.hasReadyCompanionGrowthAction {
                    Label(
                        AppLocalization.string("companion.action.ready"),
                        systemImage: "bolt.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text(AppLocalization.format(
                        "companion.energy.balanceValue",
                        self.store.companionState.availableGrowthEnergy))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
        }
        .tint(.secondary)
        .padding(TokeniLayout.cardPadding)
        .background(
            .quaternary.opacity(0.38),
            in: RoundedRectangle(cornerRadius: TokeniLayout.cornerRadius))
    }

    private var companionSummaryName: String {
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
                self.openWindow(id: "usage-history")
                self.activateApplication()
            } label: {
                Label(
                    AppLocalization.string("history.title"),
                    systemImage: "chart.xyaxis.line")
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                self.openSettings()
                self.activateApplication()
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
}
