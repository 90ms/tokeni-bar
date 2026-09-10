import AppKit
import SwiftUI
import TokeniCore

enum TokeniMainDestination: String, CaseIterable, Hashable, Identifiable {
    case home
    case usage
    case pets
    case settings

    var id: Self { self }

    var localizationKey: String {
        "main.navigation.\(self.rawValue)"
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .usage: "chart.xyaxis.line"
        case .pets: "pawprint.fill"
        case .settings: "gearshape.fill"
        }
    }
}

@MainActor
final class TokeniMainNavigation: ObservableObject {
    @Published var selection: TokeniMainDestination?
    @Published private(set) var focusedUsageProviderID: ProviderID?
    @Published private(set) var usageFocusPulse = 0

    init(selection: TokeniMainDestination = .home) {
        self.selection = selection
    }

    var destination: TokeniMainDestination {
        self.selection ?? .home
    }

    func select(_ destination: TokeniMainDestination) {
        self.selection = destination
    }

    func selectUsage(providerID: ProviderID) {
        self.focusedUsageProviderID = providerID
        self.usageFocusPulse &+= 1
        self.selection = .usage
    }
}

struct TokeniMainView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var caffeineController: CaffeineController
    @ObservedObject var navigation: TokeniMainNavigation

    var body: some View {
        NavigationSplitView {
            List(selection: self.$navigation.selection) {
                Section {
                    ForEach(TokeniMainDestination.allCases) { destination in
                        Label(
                            AppLocalization.string(destination.localizationKey),
                            systemImage: destination.systemImage)
                            .tag(destination)
                    }
                }

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
        .onReceive(NotificationCenter.default.publisher(
            for: .openNotificationSettings))
        { _ in
            self.navigation.select(.settings)
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first(where: {
                $0.title == AppLocalization.string("main.title")
            })?.makeKeyAndOrderFront(nil)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch self.navigation.destination {
        case .home:
            TokeniHomeView(
                store: self.store,
                navigation: self.navigation)
        case .pets:
            CompanionCollectionView(store: self.store)
                .navigationTitle(AppLocalization.string(
                    TokeniMainDestination.pets.localizationKey))
        case .usage:
            TokeniUsageView(store: self.store, navigation: self.navigation)
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
    @ObservedObject var navigation: TokeniMainNavigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                self.headerView

                self.kpiSummaryRow

                HStack(alignment: .top, spacing: 16) {
                    self.providerQuotaGlanceCard
                        .frame(maxWidth: .infinity)

                    self.companionDeskGlanceCard
                        .frame(width: 320)
                }

                self.quickActionRow
            }
            .padding(28)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(AppLocalization.string(
            TokeniMainDestination.home.localizationKey))
    }

    private var headerView: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string("main.home.title"))
                    .font(.largeTitle.bold())
                Text(AppLocalization.string("main.home.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                if let lastRefresh = self.store.lastRefresh {
                    Text(lastRefresh, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(AppLocalization.string("main.home.notRefreshed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if self.store.isRefreshing {
                    ProgressView().controlSize(.small)
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
                }
            }
        }
    }

    private var kpiSummaryRow: some View {
        HStack(spacing: 12) {
            self.kpiCard(
                title: AppLocalization.string("main.home.kpi.todayTokens"),
                value: self.store.companionTodayTokens > 0
                    ? self.store.companionTodayTokens.formatted(.number)
                    : "0",
                subtitle: AppLocalization.format(
                    "main.home.kpi.todayTokensSub",
                    self.activeProviderCount),
                icon: "bolt.fill",
                color: .accentColor)

            self.kpiCard(
                title: AppLocalization.string("main.home.kpi.quotaHealth"),
                value: self.lowestQuota.map {
                    AppLocalization.format(
                        "menu.provider.remaining",
                        Int($0.1.remainingPercent.rounded()))
                } ?? "-",
                subtitle: self.lowestQuota?.0.descriptor.displayName
                    ?? AppLocalization.string("main.home.kpi.healthy"),
                icon: "gauge.with.dots.needle.50percent",
                color: (self.lowestQuota?.1.remainingPercent ?? 100) < 20 ? .orange : .green)

            self.kpiCard(
                title: AppLocalization.string("main.home.kpi.monthlySpend"),
                value: self.store.menuBarMonthlyCost ?? "-",
                subtitle: self.store.monthlyBudgetEnabled
                    ? AppLocalization.string("settings.budget.title")
                    : self.store.costDisplayCurrency.rawValue.uppercased(),
                icon: "creditcard.fill",
                color: .blue)

            self.kpiCard(
                title: AppLocalization.string("main.home.kpi.providerStatus"),
                value: self.problemSnapshots.isEmpty
                    ? AppLocalization.string("main.home.kpi.healthy")
                    : AppLocalization.format(
                        "main.home.providerIssues",
                        self.problemSnapshots.count),
                subtitle: AppLocalization.format(
                    "main.home.providerCount",
                    self.store.snapshots.count),
                icon: self.problemSnapshots.isEmpty
                    ? "checkmark.shield.fill"
                    : "exclamationmark.triangle.fill",
                color: self.problemSnapshots.isEmpty ? .green : .orange)
        }
    }

    private func kpiCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Spacer()
                }
                .font(.subheadline)

                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private var providerQuotaGlanceCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if self.store.snapshots.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.string("empty.title"),
                        systemImage: "chart.bar",
                        description: Text(AppLocalization.string("empty.description")))
                        .frame(minHeight: 160)
                } else {
                    VStack(spacing: 8) {
                        ForEach(self.store.snapshots.prefix(5)) { snapshot in
                            Button {
                                self.navigation.selectUsage(providerID: snapshot.id)
                            } label: {
                                HStack(spacing: 10) {
                                    ProviderIcon(descriptor: snapshot.descriptor)
                                        .frame(width: 18, height: 18)

                                    Text(snapshot.descriptor.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if let primaryQuota = snapshot.quotaWindows.first {
                                        ProgressView(
                                            value: primaryQuota.remainingPercent,
                                            total: 100)
                                            .frame(width: 80)
                                            .tint(primaryQuota.remainingPercent < 20 ? .orange : .accentColor)

                                        Text(AppLocalization.format(
                                            "menu.provider.remaining",
                                            Int(primaryQuota.remainingPercent.rounded())))
                                            .font(.caption.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(primaryQuota.remainingPercent < 20 ? .orange : .secondary)
                                            .frame(width: 44, alignment: .trailing)
                                    } else {
                                        Text(snapshot.availability.localizedName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Color(nsColor: .controlBackgroundColor).opacity(0.5),
                                    in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            self.navigation.select(.usage)
                        } label: {
                            HStack(spacing: 4) {
                                Text(AppLocalization.string("main.home.viewAllUsage"))
                                Image(systemName: "arrow.right")
                            }
                            .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        } label: {
            Label(
                AppLocalization.string("main.home.providersTitle"),
                systemImage: "chart.xyaxis.line")
                .font(.headline)
        }
    }

    private var companionDeskGlanceCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                if self.store.companionEnabled {
                    HStack(spacing: 14) {
                        ByteBotTransitionView(
                            speciesID: self.store.displayedCompanionAppearanceSpeciesID,
                            stage: self.store.displayedCompanionStage,
                            rarity: self.store.displayedCompanionRarity,
                            variantID: self.store.displayedCompanionVariantID,
                            behavior: .idle,
                            mutationID: self.store.displayedCompanionMutationID,
                            cosmeticIDs: self.store.companionRewardState.selectedCosmeticIDs,
                            dimension: 64,
                            animationsEnabled: self.store.companionAnimationsEnabled,
                            animationIntensity: self.store.companionAnimationIntensity.scale,
                            interactionPulse: self.store.companionInteractionPulse,
                            growthPulse: self.store.companionGrowthPulse)
                            .onTapGesture {
                                self.store.patCompanion()
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(self.store.companionState.nickname
                                ?? AppLocalization.string(
                                    "companion.species.\(self.store.displayedCompanionAppearanceSpeciesID.rawValue).name"))
                                .font(.headline)

                            HStack(spacing: 6) {
                                Text(AppLocalization.format(
                                    "companion.level.value",
                                    self.store.companionState.growthTargetLevel))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Color.accentColor.opacity(0.12),
                                        in: Capsule())

                                Text(AppLocalization.string(
                                    "companion.stage.\(self.store.displayedCompanionStage.rawValue)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if self.store.hasReadyCompanionGrowthAction {
                                Label(
                                    AppLocalization.string("main.home.growthReady"),
                                    systemImage: "sparkles")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }

                        Spacer()
                    }
                    .padding(.top, 2)

                    Text(AppLocalization.string("main.home.companionGreeting"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(
                            Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 6))

                    Button {
                        self.navigation.select(.pets)
                    } label: {
                        HStack(spacing: 4) {
                            Text(AppLocalization.string("main.home.managePets"))
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    ContentUnavailableView(
                        AppLocalization.string("settings.companion.disabled.title"),
                        systemImage: "pawprint",
                        description: Text(AppLocalization.string("settings.companion.disabled.description")))
                        .frame(minHeight: 140)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        } label: {
            Label(
                AppLocalization.string("main.home.companionDesk"),
                systemImage: "pawprint.fill")
                .font(.headline)
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 12) {
            Button {
                self.navigation.select(.usage)
            } label: {
                Label(
                    AppLocalization.string("main.home.openUsage"),
                    systemImage: TokeniMainDestination.usage.systemImage)
            }
            .buttonStyle(.borderedProminent)

            Button {
                self.navigation.select(.pets)
            } label: {
                Label(
                    AppLocalization.string("main.home.openPets"),
                    systemImage: TokeniMainDestination.pets.systemImage)
            }
            .buttonStyle(.bordered)

            Button {
                self.navigation.select(.settings)
            } label: {
                Label(
                    AppLocalization.string(TokeniMainDestination.settings.localizationKey),
                    systemImage: TokeniMainDestination.settings.systemImage)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private var activeProviderCount: Int {
        self.store.snapshots.filter { $0.availability == .available }.count
    }

    private var lowestQuota: (ProviderSnapshot, QuotaWindow)? {
        self.store.snapshots.compactMap { snapshot in
            snapshot.quotaWindows.min(by: {
                $0.remainingPercent < $1.remainingPercent
            }).map { (snapshot, $0) }
        }.min(by: { $0.1.remainingPercent < $1.1.remainingPercent })
    }

    private var problemSnapshots: [ProviderSnapshot] {
        self.store.snapshots.filter {
            $0.availability == .stale
                || $0.availability == .unavailable
                || $0.availability == .failed
        }
    }
}

private struct TokeniUsageView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var navigation: TokeniMainNavigation

    var body: some View {
        ScrollViewReader { proxy in
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
                                .id(snapshot.id)
                        }
                    }
                }

                Divider()

                HistoryView(store: self.store)
                    .frame(minHeight: 480)
            }
                .padding(28)
            }
            .onAppear {
                self.scrollToFocusedProvider(using: proxy, animated: false)
            }
            .onChange(of: self.navigation.usageFocusPulse) { _, _ in
                self.scrollToFocusedProvider(using: proxy, animated: true)
            }
        }
    }

    private func scrollToFocusedProvider(
        using proxy: ScrollViewProxy,
        animated: Bool)
    {
        guard let providerID = self.navigation.focusedUsageProviderID else { return }
        if animated {
            withAnimation { proxy.scrollTo(providerID, anchor: .top) }
        } else {
            proxy.scrollTo(providerID, anchor: .top)
        }
    }
}
