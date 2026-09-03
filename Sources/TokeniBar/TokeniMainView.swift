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

    init(selection: TokeniMainDestination = .home) {
        self.selection = selection
    }

    var destination: TokeniMainDestination {
        self.selection ?? .home
    }

    func select(_ destination: TokeniMainDestination) {
        self.selection = destination
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
                navigate: { self.navigation.select($0) })
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
    let navigate: (TokeniMainDestination) -> Void

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
                    if let growthTarget = self.store.companionState.growthTargetPet {
                        self.growthTargetSummary(growthTarget)
                    } else {
                        self.eggSummary
                    }
                } else {
                    ContentUnavailableView(
                        AppLocalization.string(
                            "settings.companion.disabled.title"),
                        systemImage: "pawprint",
                        description: Text(AppLocalization.string(
                            "settings.companion.disabled.description")))
                }

                self.usageSummary

                HStack(spacing: 12) {
                    Button {
                        self.navigate(.pets)
                    } label: {
                        Label(
                            AppLocalization.string("main.home.openPets"),
                            systemImage: TokeniMainDestination.pets.systemImage)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        self.navigate(.usage)
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

    private func growthTargetSummary(
        _ target: CompanionRolePet
    ) -> some View {
        GroupBox {
            HStack(alignment: .center, spacing: 14) {
                ByteBotSpriteView(
                    speciesID: target.speciesID,
                    stage: target.stage,
                    rarity: target.rarity,
                    variantID: target.variantID,
                    behavior: .idle,
                    dimension: 56,
                    animationsEnabled: false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(target.nickname ?? AppLocalization.string(
                            "companion.species.\(target.speciesID.rawValue).name"))
                            .font(.headline)
                        if self.store.companionState.roleSelection
                            .primaryGenerationID == target.generationID
                        {
                            Text(AppLocalization.string(
                                "main.home.primaryAndGrowth"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Color.accentColor.opacity(0.12),
                                    in: Capsule())
                        }
                    }

                    HStack {
                        Text(AppLocalization.format(
                            "companion.level.value",
                            target.level))
                        Text("·")
                        Text(AppLocalization.string(
                            "companion.stage.\(target.stage.rawValue)"))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ProgressView(value: target.levelProgress)
                        .accessibilityLabel(AppLocalization.string(
                            "main.home.growthTarget"))
                        .accessibilityValue(AppLocalization.format(
                            "companion.level.value",
                            target.level))
                }

                Spacer()

                Button(AppLocalization.string(
                    "main.home.manageGrowthTarget"))
                {
                    self.navigate(.pets)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(
                AppLocalization.string("main.home.growthTarget"),
                systemImage: "scope")
                .font(.headline)
        }
    }

    private var eggSummary: some View {
        GroupBox {
            HStack(spacing: 14) {
                ByteBotTransitionView(
                    speciesID: self.store.displayedCompanionAppearanceSpeciesID,
                    stage: self.store.displayedCompanionStage,
                    rarity: self.store.displayedCompanionRarity,
                    variantID: self.store.displayedCompanionVariantID,
                    behavior: .idle,
                    mutationID: self.store.displayedCompanionMutationID,
                    cosmeticIDs: self.store.companionRewardState.selectedCosmeticIDs,
                    dimension: 56,
                    animationsEnabled: false,
                    animationIntensity: 0,
                    interactionPulse: 0,
                    growthPulse: 0)

                VStack(alignment: .leading, spacing: 5) {
                    Text(AppLocalization.string("companion.species.mystery.name"))
                        .font(.headline)
                    Text(AppLocalization.string(
                        "companion.stage.\(self.store.displayedCompanionStage.rawValue)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(AppLocalization.string("main.home.openPets")) {
                    self.navigate(.pets)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(
                AppLocalization.string("main.home.growthTarget"),
                systemImage: "pawprint.fill")
                .font(.headline)
        }
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
