import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    if self.store.companionMigrationQuote != nil
                        || self.store.companionMigrationReceiptNoticeVisible
                    {
                        CompanionMigrationCard(
                            store: self.store,
                            showsReceiptDismissButton: true)
                        Divider()
                            .padding(.vertical, 10)
                    }

                    if self.store.companionEnabled {
                        CompanionCard(
                            store: self.store,
                            compact: self.store.compactModeEnabled)
                        Divider()
                            .padding(.vertical, 10)
                    }

                    if !self.store.snapshots.isEmpty {
                        HStack {
                            Text(AppLocalization.string("settings.tab.usage"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.bottom, 7)
                    }

                    self.providerContent

                    if let result = self.store.appUpdateResult,
                       result.isUpdateAvailable
                    {
                        self.updateBanner(
                            version: result.latestRelease.version.description,
                            destination: result.latestRelease.pageURL)
                            .padding(.top, 10)
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
                .help(AppLocalization.string("action.refresh"))
                .accessibilityLabel(AppLocalization.string("action.refresh"))
            }
        }
    }

    @ViewBuilder
    private var providerContent: some View {
        if self.store.snapshots.isEmpty {
            ContentUnavailableView(
                AppLocalization.string("empty.title"),
                systemImage: "chart.bar",
                description: Text(AppLocalization.string("empty.description")))
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
            .help(AppLocalization.string("action.settings"))
            .accessibilityLabel(AppLocalization.string("action.settings"))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
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
