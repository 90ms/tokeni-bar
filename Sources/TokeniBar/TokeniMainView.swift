import AppKit
import SwiftUI

enum TokeniMainDestination: String, CaseIterable, Hashable, Identifiable {
    case home
    case pets
    case usage
    case settings

    var id: Self { self }

    var localizationKey: String {
        "main.navigation.\(self.rawValue)"
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .pets: "pawprint.fill"
        case .usage: "chart.xyaxis.line"
        case .settings: "gearshape.fill"
        }
    }
}

struct TokeniMainView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var caffeineController: CaffeineController
    @State private var selection = TokeniMainDestination.home

    var body: some View {
        NavigationSplitView {
            List(TokeniMainDestination.allCases, selection: self.$selection) {
                destination in
                Label(
                    AppLocalization.string(destination.localizationKey),
                    systemImage: destination.systemImage)
                    .tag(destination)
            }
            .navigationTitle(AppLocalization.string("main.title"))
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } detail: {
            self.detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            self.store.start()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch self.selection {
        case .home:
            TokeniHomeView(
                store: self.store,
                caffeineController: self.caffeineController,
                selection: self.$selection)
        case .pets:
            CompanionCollectionView(store: self.store)
                .navigationTitle(AppLocalization.string(
                    TokeniMainDestination.pets.localizationKey))
        case .usage:
            TokeniUsageView(store: self.store)
                .navigationTitle(AppLocalization.string(
                    TokeniMainDestination.usage.localizationKey))
        case .settings:
            SettingsView(
                store: self.store,
                caffeineController: self.caffeineController)
                .navigationTitle(AppLocalization.string(
                    TokeniMainDestination.settings.localizationKey))
        }
    }
}

private struct TokeniHomeView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var caffeineController: CaffeineController
    @Binding var selection: TokeniMainDestination

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppLocalization.string("main.home.title"))
                        .font(.largeTitle.bold())
                    Text(AppLocalization.string("main.home.subtitle"))
                        .foregroundStyle(.secondary)
                }

                if self.store.companionEnabled {
                    CompanionCard(store: self.store)
                } else {
                    ContentUnavailableView(
                        AppLocalization.string(
                            "settings.companion.disabled.title"),
                        systemImage: "pawprint",
                        description: Text(AppLocalization.string(
                            "settings.companion.disabled.description")))
                }

                HStack(alignment: .top, spacing: 16) {
                    self.usageSummary
                    self.caffeineSummary
                }

                HStack(spacing: 12) {
                    Button {
                        self.selection = .pets
                    } label: {
                        Label(
                            AppLocalization.string("main.home.openPets"),
                            systemImage: TokeniMainDestination.pets.systemImage)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        self.selection = .usage
                    } label: {
                        Label(
                            AppLocalization.string("main.home.openUsage"),
                            systemImage: TokeniMainDestination.usage.systemImage)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
            .padding(28)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(AppLocalization.string(
            TokeniMainDestination.home.localizationKey))
    }

    private var usageSummary: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        AppLocalization.format(
                            "main.home.providerCount",
                            self.store.snapshots.count),
                        systemImage: "waveform.path.ecg")
                    Spacer()
                    if self.store.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let lastRefresh = self.store.lastRefresh {
                    HStack(spacing: 4) {
                        Text(AppLocalization.string("usage.updated"))
                        Text(lastRefresh, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(AppLocalization.string("main.home.notRefreshed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(AppLocalization.string("action.refresh")) {
                    Task {
                        await self.store.refresh(forceProviderReload: true)
                    }
                }
                .disabled(self.store.isRefreshing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(AppLocalization.string("main.home.usageSummary"))
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }

    private var caffeineSummary: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    AppLocalization.string(
                        self.caffeineController.isEnabled
                            ? "main.home.caffeineOn"
                            : "main.home.caffeineOff"),
                    systemImage: self.caffeineController.isEnabled
                        ? "cup.and.saucer.fill"
                        : "cup.and.saucer")
                    .foregroundStyle(
                        self.caffeineController.isEnabled
                            ? Color.orange
                            : Color.primary)

                Text(AppLocalization.string("main.home.caffeineDescription"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(AppLocalization.string(
                    self.caffeineController.isEnabled
                        ? "caffeine.disable"
                        : "caffeine.enable"))
                {
                    self.caffeineController.toggle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(AppLocalization.string("settings.caffeine.title"))
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TokeniUsageView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLocalization.string("main.usage.title"))
                            .font(.largeTitle.bold())
                        Text(AppLocalization.string("main.usage.subtitle"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            await self.store.refresh(forceProviderReload: true)
                        }
                    } label: {
                        Label(
                            AppLocalization.string("action.refresh"),
                            systemImage: "arrow.clockwise")
                    }
                    .disabled(self.store.isRefreshing)
                }

                if self.store.snapshots.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.string("empty.title"),
                        systemImage: "chart.bar",
                        description: Text(AppLocalization.string(
                            "empty.description")))
                        .frame(minHeight: 180)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 280), spacing: 12),
                        ],
                        spacing: 12)
                    {
                        ForEach(self.store.snapshots) { snapshot in
                            ProviderRow(
                                snapshot: snapshot,
                                costCurrency: self.store.costDisplayCurrency,
                                exchangeRate: self.store.exchangeRateQuote,
                                compact: false,
                                isActive: self.store.activityAnimationsEnabled
                                    && self.store.isActive(snapshot.id))
                        }
                    }
                }

                Divider()

                HistoryView(store: self.store)
                    .frame(minHeight: 480)
            }
            .padding(28)
        }
    }
}
