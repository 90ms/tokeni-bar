import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            self.header
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    if self.store.companionEnabled {
                        CompanionCard(
                            store: self.store,
                            compact: self.store.compactModeEnabled)
                        Divider()
                            .padding(.vertical, 10)
                    }

                    self.providerContent

                    if let result = self.store.appUpdateResult,
                       result.isUpdateAvailable
                    {
                        Divider()
                            .padding(.vertical, 8)
                        Link(destination: result.latestRelease.pageURL) {
                            Label(
                                AppLocalization.format(
                                    "updates.menuAvailable",
                                    result.latestRelease.version.description),
                                systemImage: "arrow.down.circle")
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 560)

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
        HStack {
            Button(AppLocalization.string("action.settings")) {
                self.openSettings()
                Task { @MainActor in
                    await Task.yield()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(AppLocalization.string("action.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
    }
}
