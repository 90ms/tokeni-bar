import TokeniCore
import AppKit
import Foundation

struct CompanionGrowthProviderBreakdown: Identifiable, Equatable {
    let descriptor: ProviderDescriptor
    let reflectedTokens: Int64?
    let usageDateKey: String?
    let wasSettledToday: Bool
    let isTodayPending: Bool
    let accountIssue: AccountTokenUsageIssue?

    var id: ProviderID { self.descriptor.id }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderSnapshot]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var enabledProviderIDs: Set<ProviderID>
    @Published private(set) var notificationsEnabled: Bool
    @Published private(set) var notificationSettingsMessage: String?
    @Published private(set) var warningThreshold: Int
    @Published private(set) var criticalThreshold: Int
    @Published private(set) var lowUsageNotificationsEnabled: Bool
    @Published private(set) var resetNotificationsEnabled: Bool
    @Published private(set) var connectionIssueNotificationsEnabled: Bool
    @Published private(set) var budgetNotificationsEnabled: Bool
    @Published private(set) var notificationQuietHoursEnabled: Bool
    @Published private(set) var notificationQuietHoursStart: Int
    @Published private(set) var notificationQuietHoursEnd: Int
    @Published private(set) var notificationDiagnostics: [String]
    @Published private(set) var notificationProviderIDs: Set<ProviderID>
    @Published private(set) var authorizingProviderIDs: Set<ProviderID>
    @Published private(set) var providerAuthorizationMessages: [ProviderID: String]
    @Published private(set) var menuBarDisplayMode: MenuBarDisplayMode
    @Published private(set) var selectedMenuBarProviderID: ProviderID
    @Published private(set) var claudeMenuBarQuota: ClaudeMenuBarQuota
    @Published private(set) var compactModeEnabled: Bool
    @Published private(set) var activityAnimationsEnabled: Bool
    @Published private(set) var activityWindowSeconds: Int
    @Published private(set) var providerActivities: [ProviderID: ProviderActivitySnapshot]
    @Published private(set) var activityAnimationPulse: Int
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginMessage: String?
    @Published private(set) var historyRecords: [UsageHistoryRecord]
    @Published private(set) var costDisplayCurrency: CostDisplayCurrency
    @Published private(set) var exchangeRateQuote: ExchangeRateQuote?
    @Published private(set) var appLanguage: AppLanguage
    @Published private(set) var monthlyBudgetEnabled: Bool
    @Published private(set) var monthlyBudgetAmount: Double
    @Published private(set) var monthlyBudgetCurrency: CostDisplayCurrency
    @Published private(set) var pricingCatalogMetadata: PricingCatalogMetadata
    @Published private(set) var pricingCatalogSource: PricingCatalogSource
    @Published private(set) var pricingUpdateMessage: String?
    @Published private(set) var appUpdateResult: AppUpdateCheckResult?
    @Published private(set) var isCheckingForAppUpdate: Bool
    @Published private(set) var appUpdateMessage: String?
    @Published private(set) var isInstallingAppUpdate: Bool
    @Published private(set) var appUpdateInstallationOperation: HomebrewUpdateOperation?
    @Published private(set) var appUpdateInstallationMessage: String?
    @Published private(set) var appUpdateRequiresFormulaMigration: Bool
    @Published private(set) var companionEnabled: Bool
    @Published private(set) var companionAnimationsEnabled: Bool
    @Published private(set) var companionAnimationIntensity:
        CompanionAnimationIntensity
    @Published private(set) var companionOverlayEnabled: Bool
    @Published private(set) var companionOverlaySize: CompanionOverlaySize
    @Published private(set) var companionOverlayPositionLocked: Bool
    @Published private(set) var companionOverlayClickThroughEnabled: Bool
    @Published private(set) var companionOverlayPositionResetPulse: Int
    @Published private(set) var companionInteractionPulse: Int
    @Published private(set) var companionGrowthPulse: Int
    @Published private(set) var companionState: CompanionGameState
    @Published private(set) var companionReveal: CompanionHatchReveal?
    @Published private(set) var companionHatchBatchReveal:
        CompanionHatchBatchReveal? = nil
    @Published private(set) var companionCelebration: CompanionCelebration?
    @Published private(set) var companionMutationReveal: CompanionMutationReveal?
    @Published private(set) var companionMutationErrorMessage: String?
    @Published private(set) var isCompanionEvolving: Bool
    @Published private(set) var companionRewardState: CompanionRewardState
    @Published private(set) var companionBenefitState: CompanionBenefitState
    @Published private(set) var companionBenefitError: CompanionBenefitError?
    @Published private(set) var companionRewardNoticeAmount: Int?
    @Published private(set) var companionAttendanceError: CompanionRewardError?
    @Published private(set) var companionDataUnavailable: Bool
    @Published private(set) var companionGrowthDataUnavailable: Bool
    @Published private(set) var companionEconomyTransactionInFlight: Bool
    @Published private(set) var companionEconomyErrorMessage: String?

    private let providers: [any UsageProviding]
    private var refreshLoop: Task<Void, Never>?
    private var activityLoop: Task<Void, Never>?
    private let notificationController: UsageNotificationController
    private let launchAtLoginController: LaunchAtLoginController
    private let historyStore: UsageHistoryStore
    private let exchangeRateClient: DailyExchangeRateClient
    private let pricingCatalogClient: PricingCatalogUpdateClient
    private let appUpdateClient: GitHubReleaseUpdateClient
    private let homebrewUpdateService: HomebrewUpdateService
    private let companionStateStore: CompanionGameStateStore
    private let companionRewardStateStore: CompanionRewardStateStore
    private let companionBenefitStateStore: CompanionBenefitStateStore
    private let companionEconomyTransactionStore:
        CompanionEconomyTransactionStore
    private let tokenGrowthLedgerStore: TokenGrowthLedgerStore
    private let companionGameEngine = CompanionGameEngine()
    private let companionRewardEngine = CompanionRewardEngine()
    private let companionBenefitEngine = CompanionBenefitEngine()
    private let tokenGrowthLedgerEngine = TokenGrowthLedgerEngine()
    private var tokenGrowthLedgerState: TokenGrowthLedgerState
    private var companionStateLoaded = false
    private var companionStateSaveRevision: UInt64 = 0
    private var companionRewardSaveRevision: UInt64 = 0
    private var companionBenefitSaveRevision: UInt64 = 0
    private var tokenGrowthLedgerSaveRevision: UInt64 = 0
    private var lastCompanionActivityPersistenceAt: Date?
    private var appUpdateInstallationTask: Task<Void, Never>?
    private static let enabledProvidersKey = "enabledProviderIDs"
    private static let legacyShowsRemainingInMenuBarKey = "showsRemainingInMenuBar"
    private static let menuBarDisplayModeKey = "menuBarDisplayMode"
    private static let selectedMenuBarProviderIDKey = "selectedMenuBarProviderID"
    private static let claudeMenuBarQuotaKey = "claudeMenuBarQuota"
    private static let compactModeEnabledKey = "compactModeEnabled"
    private static let activityAnimationsEnabledKey = "activityAnimationsEnabled"
    private static let activityWindowSecondsKey = "activityWindowSeconds"
    private static let supportedActivityWindows = [10, 15, 30]
    private static let warningThresholdKey = "usageNotificationWarningThreshold"
    private static let criticalThresholdKey = "usageNotificationCriticalThreshold"
    private static let lowUsageNotificationsEnabledKey =
        "usageLowNotificationsEnabled"
    private static let resetNotificationsEnabledKey =
        "usageResetNotificationsEnabled"
    private static let connectionIssueNotificationsEnabledKey =
        "usageConnectionIssueNotificationsEnabled"
    private static let budgetNotificationsEnabledKey =
        "usageBudgetNotificationsEnabled"
    private static let notificationQuietHoursEnabledKey =
        "usageNotificationQuietHoursEnabled"
    private static let notificationQuietHoursStartKey =
        "usageNotificationQuietHoursStart"
    private static let notificationQuietHoursEndKey =
        "usageNotificationQuietHoursEnd"
    private static let notificationProviderIDsKey = "usageNotificationProviderIDs"
    private static let costDisplayCurrencyKey = "costDisplayCurrency"
    private static let monthlyBudgetEnabledKey = "monthlyBudgetEnabled"
    private static let monthlyBudgetAmountKey = "monthlyBudgetAmount"
    private static let monthlyBudgetCurrencyKey = "monthlyBudgetCurrency"
    private static let pricingCatalogLastCheckKey = "pricingCatalogLastCheck"
    private static let companionEnabledKey = "companionEnabled"
    private static let companionAnimationsEnabledKey = "companionAnimationsEnabled"
    private static let activityRefreshInterval: Duration = .seconds(10)
    private static let companionActivityPersistenceInterval: TimeInterval = 60
    private static let companionAnimationIntensityKey =
        "companionAnimationIntensity"
    private static let companionOverlayEnabledKey = "companionOverlayEnabled"
    private static let companionOverlaySizeKey = "companionOverlaySize"
    private static let companionOverlayPositionLockedKey =
        "companionOverlayPositionLocked"
    private static let companionOverlayClickThroughEnabledKey =
        "companionOverlayClickThroughEnabled"

    init(providers: [any UsageProviding] = ProviderRegistry.defaultProviders()) {
        let knownIDs = Set(providers.map { $0.descriptor.id })
        self.providers = providers
        let notificationController = UsageNotificationController()
        let launchAtLoginController = LaunchAtLoginController()
        let historyStore = UsageHistoryStore()
        let exchangeRateClient = DailyExchangeRateClient()
        let pricingCatalogClient = PricingCatalogUpdateClient()
        let appUpdateClient = GitHubReleaseUpdateClient()
        let homebrewUpdateService = HomebrewUpdateService()
        let companionStateStore = CompanionGameStateStore()
        let companionRewardStateStore = CompanionRewardStateStore()
        let companionBenefitStateStore = CompanionBenefitStateStore()
        let companionEconomyTransactionStore =
            CompanionEconomyTransactionStore()
        let tokenGrowthLedgerStore = TokenGrowthLedgerStore()
        self.notificationController = notificationController
        self.launchAtLoginController = launchAtLoginController
        self.historyStore = historyStore
        self.exchangeRateClient = exchangeRateClient
        self.pricingCatalogClient = pricingCatalogClient
        self.appUpdateClient = appUpdateClient
        self.homebrewUpdateService = homebrewUpdateService
        self.companionStateStore = companionStateStore
        self.companionRewardStateStore = companionRewardStateStore
        self.companionBenefitStateStore = companionBenefitStateStore
        self.companionEconomyTransactionStore =
            companionEconomyTransactionStore
        self.tokenGrowthLedgerStore = tokenGrowthLedgerStore
        self.tokenGrowthLedgerState = TokenGrowthLedgerState()
        self.notificationsEnabled = notificationController.isEnabled
        self.notificationSettingsMessage = nil
        self.authorizingProviderIDs = []
        self.providerAuthorizationMessages = [:]
        self.warningThreshold = UserDefaults.standard.object(forKey: Self.warningThresholdKey) as? Int ?? 30
        self.criticalThreshold = UserDefaults.standard.object(forKey: Self.criticalThresholdKey) as? Int ?? 10
        self.lowUsageNotificationsEnabled = UserDefaults.standard.object(
            forKey: Self.lowUsageNotificationsEnabledKey) as? Bool ?? true
        self.resetNotificationsEnabled = UserDefaults.standard.object(
            forKey: Self.resetNotificationsEnabledKey) as? Bool ?? true
        self.connectionIssueNotificationsEnabled = UserDefaults.standard.object(
            forKey: Self.connectionIssueNotificationsEnabledKey) as? Bool ?? false
        self.budgetNotificationsEnabled = UserDefaults.standard.object(
            forKey: Self.budgetNotificationsEnabledKey) as? Bool ?? true
        self.notificationQuietHoursEnabled = UserDefaults.standard.bool(
            forKey: Self.notificationQuietHoursEnabledKey)
        self.notificationQuietHoursStart = UserDefaults.standard.object(
            forKey: Self.notificationQuietHoursStartKey) as? Int ?? 22
        self.notificationQuietHoursEnd = UserDefaults.standard.object(
            forKey: Self.notificationQuietHoursEndKey) as? Int ?? 8
        self.notificationDiagnostics = []
        if let storedMode = UserDefaults.standard.string(forKey: Self.menuBarDisplayModeKey)
            .flatMap(MenuBarDisplayMode.init(rawValue:))
        {
            self.menuBarDisplayMode = storedMode
        } else if UserDefaults.standard.object(
            forKey: Self.legacyShowsRemainingInMenuBarKey) as? Bool == false
        {
            self.menuBarDisplayMode = .iconOnly
        } else {
            self.menuBarDisplayMode = .lowestRemaining
        }
        let storedMenuBarProviderID = UserDefaults.standard.string(
            forKey: Self.selectedMenuBarProviderIDKey).map(ProviderID.init(rawValue:))
        self.selectedMenuBarProviderID = storedMenuBarProviderID
            .flatMap { knownIDs.contains($0) ? $0 : nil }
            ?? providers.first?.descriptor.id
            ?? .codex
        self.claudeMenuBarQuota = UserDefaults.standard.string(
            forKey: Self.claudeMenuBarQuotaKey)
            .flatMap(ClaudeMenuBarQuota.init(rawValue:)) ?? .fable
        self.compactModeEnabled = UserDefaults.standard.bool(forKey: Self.compactModeEnabledKey)
        self.activityAnimationsEnabled = UserDefaults.standard.object(
            forKey: Self.activityAnimationsEnabledKey) as? Bool ?? true
        let storedActivityWindow = UserDefaults.standard.integer(
            forKey: Self.activityWindowSecondsKey)
        self.activityWindowSeconds = Self.supportedActivityWindows.contains(storedActivityWindow)
            ? storedActivityWindow
            : 15
        self.providerActivities = Dictionary(uniqueKeysWithValues: providers.map {
            ($0.descriptor.id, ProviderActivitySnapshot(
                providerID: $0.descriptor.id,
                state: .unknown))
        })
        self.activityAnimationPulse = 0
        self.launchAtLoginEnabled = launchAtLoginController.isEnabled
        self.launchAtLoginMessage = launchAtLoginController.statusMessage
        self.historyRecords = []
        let costDisplayCurrency = UserDefaults.standard.string(
            forKey: Self.costDisplayCurrencyKey)
            .flatMap(CostDisplayCurrency.init(rawValue:)) ?? .defaultValue
        self.costDisplayCurrency = costDisplayCurrency
        self.exchangeRateQuote = nil
        self.appLanguage = .savedValue
        self.monthlyBudgetEnabled = UserDefaults.standard.bool(
            forKey: Self.monthlyBudgetEnabledKey)
        self.monthlyBudgetAmount = UserDefaults.standard.object(
            forKey: Self.monthlyBudgetAmountKey) as? Double ?? 25
        self.monthlyBudgetCurrency = UserDefaults.standard.string(
            forKey: Self.monthlyBudgetCurrencyKey)
            .flatMap(CostDisplayCurrency.init(rawValue:)) ?? costDisplayCurrency
        self.pricingCatalogMetadata = TokenPricingCatalog.metadata
        self.pricingCatalogSource = .bundled
        self.pricingUpdateMessage = nil
        self.appUpdateResult = nil
        self.isCheckingForAppUpdate = false
        self.appUpdateMessage = nil
        self.isInstallingAppUpdate = false
        self.appUpdateInstallationOperation = nil
        self.appUpdateInstallationMessage = nil
        self.appUpdateRequiresFormulaMigration = false
        self.companionEnabled = UserDefaults.standard.object(
            forKey: Self.companionEnabledKey) as? Bool ?? true
        let legacyCompanionAnimationsEnabled = UserDefaults.standard.object(
            forKey: Self.companionAnimationsEnabledKey) as? Bool ?? true
        let companionAnimationIntensity = UserDefaults.standard.string(
            forKey: Self.companionAnimationIntensityKey)
            .flatMap(CompanionAnimationIntensity.init(rawValue:))
            ?? (legacyCompanionAnimationsEnabled ? .full : .off)
        self.companionAnimationIntensity = companionAnimationIntensity
        self.companionAnimationsEnabled =
            companionAnimationIntensity.isEnabled
        self.companionOverlayEnabled = UserDefaults.standard.bool(
            forKey: Self.companionOverlayEnabledKey)
        self.companionOverlaySize = UserDefaults.standard.string(
            forKey: Self.companionOverlaySizeKey)
            .flatMap(CompanionOverlaySize.init(rawValue:)) ?? .medium
        self.companionOverlayPositionLocked = UserDefaults.standard.bool(
            forKey: Self.companionOverlayPositionLockedKey)
        self.companionOverlayClickThroughEnabled = UserDefaults.standard.bool(
            forKey: Self.companionOverlayClickThroughEnabledKey)
        self.companionOverlayPositionResetPulse = 0
        self.companionInteractionPulse = 0
        self.companionGrowthPulse = 0
        self.companionState = CompanionGameState()
        self.companionReveal = nil
        self.companionCelebration = nil
        self.companionMutationReveal = nil
        self.companionMutationErrorMessage = nil
        self.isCompanionEvolving = false
        self.companionRewardState = CompanionRewardState()
        self.companionBenefitState = CompanionBenefitState()
        self.companionBenefitError = nil
        self.companionRewardNoticeAmount = nil
        self.companionAttendanceError = nil
        self.companionDataUnavailable = false
        self.companionGrowthDataUnavailable = false
        self.companionEconomyTransactionInFlight = false
        self.companionEconomyErrorMessage = nil
        let enabledIDs: Set<ProviderID>
        if let stored = UserDefaults.standard.stringArray(forKey: Self.enabledProvidersKey) {
            enabledIDs = Set(stored.map { ProviderID(rawValue: $0) }).intersection(knownIDs)
        } else {
            enabledIDs = knownIDs
        }
        self.enabledProviderIDs = enabledIDs
        if let stored = UserDefaults.standard.stringArray(forKey: Self.notificationProviderIDsKey) {
            self.notificationProviderIDs = Set(stored.map { ProviderID(rawValue: $0) }).intersection(knownIDs)
        } else {
            self.notificationProviderIDs = knownIDs
        }
        self.snapshots = providers
            .filter { enabledIDs.contains($0.descriptor.id) }
            .map { .loading($0.descriptor) }
        Task { [weak self] in
            guard let self else { return }
            do {
                self.companionState = try await self.companionStateStore.load()
                self.companionRewardState = try await self
                    .companionRewardStateStore.load()
                let economyJournal = try await self
                    .companionEconomyTransactionStore.load()
                try await self.recoverCompanionEconomyTransactions(
                    economyJournal)
                self.companionGameEngine.rollOverEnergyIfNeeded(
                    in: &self.companionState)
                self.companionGameEngine.reconcileEggMilestones(
                    at: .now,
                    in: &self.companionState)
                self.suppressImportedCompanionRewardBackfill()
                self.reconcileLegacyCompanionPalettes()
                self.reconcileCompanionRewards()
                self.companionStateLoaded = true
                self.saveCompanionState()
                self.saveCompanionRewardState()
            } catch {
                self.companionDataUnavailable = true
                self.companionStateLoaded = false
            }
            do {
                self.tokenGrowthLedgerState = try await self
                    .tokenGrowthLedgerStore.load()
            } catch {
                self.companionGrowthDataUnavailable = true
            }
            if self.companionStateLoaded {
                await self.applyPendingCompanionGrowthAwards()
            }
            self.historyRecords = (try? await self.historyStore.records()) ?? []
            let cachedPricing = await self.pricingCatalogClient.activateCachedCatalog()
            self.applyPricingCatalogResult(cachedPricing)
            await self.refreshPricingCatalogIfNeeded()
            await self.refreshExchangeRate()
            self.processBudgetAlert()
            await self.checkForAppUpdate()
        }
    }

    deinit {
        self.refreshLoop?.cancel()
        self.activityLoop?.cancel()
        self.appUpdateInstallationTask?.cancel()
    }

    func start() {
        if self.refreshLoop == nil {
            self.refreshLoop = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refresh()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
        self.startActivityLoopIfNeeded()
    }

    func refresh(forceProviderReload: Bool = false) async {
        guard !self.isRefreshing else { return }
        self.isRefreshing = true
        let activeProviders = self.providers.filter { self.enabledProviderIDs.contains($0.descriptor.id) }

        if forceProviderReload {
            for provider in activeProviders {
                if let cachedProvider = provider as? any UsageCacheInvalidating {
                    await cachedProvider.invalidateUsageCache()
                }
            }
        }

        let results = await withTaskGroup(of: ProviderSnapshot.self, returning: [ProviderSnapshot].self) { group in
            for provider in activeProviders {
                group.addTask { await provider.fetchUsage() }
            }
            var collected: [ProviderSnapshot] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        let order = Dictionary(uniqueKeysWithValues: activeProviders.enumerated().map { ($1.descriptor.id, $0) })
        self.snapshots = results.sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
        self.notificationDiagnostics = self.notificationController.process(
            self.snapshots,
            history: self.historyRecords,
            warningThreshold: self.warningThreshold,
            criticalThreshold: self.criticalThreshold,
            preferences: self.notificationPreferences,
            enabledProviderIDs: self.notificationProviderIDs)
        self.lastRefresh = .now
        do {
            try await self.historyStore.record(self.snapshots, at: self.lastRefresh ?? .now)
            self.historyRecords = try await self.historyStore.records()
        } catch {
            // History is an optional local enhancement and must not fail provider refreshes.
        }
        await self.processCompanionGrowth(at: self.lastRefresh ?? .now)
        await self.refreshExchangeRate()
        await self.refreshPricingCatalogIfNeeded()
        self.processBudgetAlert()
        self.isRefreshing = false
    }

    func isEnabled(_ id: ProviderID) -> Bool {
        self.enabledProviderIDs.contains(id)
    }

    func connectionState(for id: ProviderID) -> ProviderConnectionState {
        guard let snapshot = self.snapshots.first(where: { $0.id == id })
        else { return .stale }
        return snapshot.connectionState
            ?? (snapshot.availability == .available ? .localOnly : .stale)
    }

    func setEnabled(_ enabled: Bool, for id: ProviderID) {
        if enabled {
            self.enabledProviderIDs.insert(id)
        } else {
            self.enabledProviderIDs.remove(id)
        }
        UserDefaults.standard.set(
            self.enabledProviderIDs.map(\.rawValue).sorted(),
            forKey: Self.enabledProvidersKey)
        self.snapshots = self.providers
            .filter { self.enabledProviderIDs.contains($0.descriptor.id) }
            .map { provider in
                self.snapshots.first(where: { $0.id == provider.descriptor.id }) ?? .loading(provider.descriptor)
            }
        Task { await self.refresh() }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        Task {
            let accepted = await self.notificationController.setEnabled(enabled)
            self.notificationsEnabled = accepted
            self.notificationSettingsMessage = enabled && !accepted
                ? AppLocalization.string("settings.notifications.denied")
                : nil
        }
    }

    func setWarningThreshold(_ threshold: Int) {
        self.warningThreshold = threshold
        UserDefaults.standard.set(threshold, forKey: Self.warningThresholdKey)
    }

    func setCriticalThreshold(_ threshold: Int) {
        self.criticalThreshold = threshold
        UserDefaults.standard.set(threshold, forKey: Self.criticalThresholdKey)
    }

    func setResetNotificationsEnabled(_ enabled: Bool) {
        self.resetNotificationsEnabled = enabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.resetNotificationsEnabledKey)
    }

    func setLowUsageNotificationsEnabled(_ enabled: Bool) {
        self.lowUsageNotificationsEnabled = enabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.lowUsageNotificationsEnabledKey)
    }

    func setConnectionIssueNotificationsEnabled(_ enabled: Bool) {
        self.connectionIssueNotificationsEnabled = enabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.connectionIssueNotificationsEnabledKey)
    }

    func setBudgetNotificationsEnabled(_ enabled: Bool) {
        self.budgetNotificationsEnabled = enabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.budgetNotificationsEnabledKey)
        self.processBudgetAlert()
    }

    func setNotificationQuietHoursEnabled(_ enabled: Bool) {
        self.notificationQuietHoursEnabled = enabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.notificationQuietHoursEnabledKey)
    }

    func setNotificationQuietHours(start: Int, end: Int) {
        self.notificationQuietHoursStart = min(max(start, 0), 23)
        self.notificationQuietHoursEnd = min(max(end, 0), 23)
        UserDefaults.standard.set(
            self.notificationQuietHoursStart,
            forKey: Self.notificationQuietHoursStartKey)
        UserDefaults.standard.set(
            self.notificationQuietHoursEnd,
            forKey: Self.notificationQuietHoursEndKey)
    }

    func isNotificationEnabled(for id: ProviderID) -> Bool {
        self.notificationProviderIDs.contains(id)
    }

    func setNotificationEnabled(_ enabled: Bool, for id: ProviderID) {
        if enabled {
            self.notificationProviderIDs.insert(id)
        } else {
            self.notificationProviderIDs.remove(id)
        }
        UserDefaults.standard.set(
            self.notificationProviderIDs.map(\.rawValue).sorted(),
            forKey: Self.notificationProviderIDsKey)
    }

    func sendTestNotification() {
        self.notificationController.sendTest()
    }

    func requestUsageAuthorization(for id: ProviderID) {
        guard !self.authorizingProviderIDs.contains(id),
              let provider = self.providers.first(where: { $0.descriptor.id == id })
                as? any UsageAuthorizationProviding
        else { return }

        self.authorizingProviderIDs.insert(id)
        self.providerAuthorizationMessages[id] = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                try await provider.requestUsageAuthorization()
                self.providerAuthorizationMessages[id] = AppLocalization.format(
                    "settings.connections.connected",
                    provider.descriptor.displayName)
                await self.refresh(forceProviderReload: true)
            } catch {
                self.providerAuthorizationMessages[id] = AppLocalization.format(
                    "settings.connections.failed",
                    provider.descriptor.displayName)
            }
            self.authorizingProviderIDs.remove(id)
        }
    }

    func clearHistory() {
        Task {
            try? await self.historyStore.clear()
            self.historyRecords = []
        }
    }

    func setCostDisplayCurrency(_ currency: CostDisplayCurrency) {
        self.costDisplayCurrency = currency
        UserDefaults.standard.set(currency.rawValue, forKey: Self.costDisplayCurrencyKey)
        if currency == .krw, self.exchangeRateQuote == nil {
            Task { await self.refreshExchangeRate() }
        }
    }

    func setAppLanguage(_ language: AppLanguage) {
        self.appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.defaultsKey)
        if self.notificationSettingsMessage != nil {
            self.notificationSettingsMessage = AppLocalization.string("settings.notifications.denied")
        }
    }

    func setMonthlyBudgetEnabled(_ enabled: Bool) {
        self.monthlyBudgetEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.monthlyBudgetEnabledKey)
        self.processBudgetAlert()
    }

    func setMonthlyBudgetAmount(_ amount: Double) {
        self.monthlyBudgetAmount = max(amount, 0)
        UserDefaults.standard.set(self.monthlyBudgetAmount, forKey: Self.monthlyBudgetAmountKey)
        self.processBudgetAlert()
    }

    func setMonthlyBudgetCurrency(_ currency: CostDisplayCurrency) {
        self.monthlyBudgetCurrency = currency
        UserDefaults.standard.set(currency.rawValue, forKey: Self.monthlyBudgetCurrencyKey)
        self.processBudgetAlert()
    }

    func refreshExchangeRate() async {
        if let quote = try? await self.exchangeRateClient.quote() {
            self.exchangeRateQuote = quote
        }
    }

    func refreshPricingCatalog() {
        Task { await self.refreshPricingCatalogIfNeeded(force: true) }
    }

    func refreshAppUpdate() {
        Task { await self.checkForAppUpdate(force: true) }
    }

    func installAppUpdate() {
        guard !self.isInstallingAppUpdate,
              self.appUpdateResult?.isUpdateAvailable == true
        else { return }
        self.isInstallingAppUpdate = true
        self.appUpdateInstallationMessage = nil
        self.appUpdateRequiresFormulaMigration = false
        self.appUpdateInstallationTask = Task { [weak self] in
            await self?.performAppUpdateInstallation()
        }
    }

    func cancelAppUpdateInstallation() {
        self.appUpdateInstallationTask?.cancel()
    }

    func setMenuBarDisplayMode(_ mode: MenuBarDisplayMode) {
        self.menuBarDisplayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.menuBarDisplayModeKey)
    }

    func setSelectedMenuBarProviderID(_ id: ProviderID) {
        guard self.descriptors.contains(where: { $0.id == id }) else { return }
        self.selectedMenuBarProviderID = id
        UserDefaults.standard.set(id.rawValue, forKey: Self.selectedMenuBarProviderIDKey)
    }

    func setClaudeMenuBarQuota(_ quota: ClaudeMenuBarQuota) {
        self.claudeMenuBarQuota = quota
        UserDefaults.standard.set(quota.rawValue, forKey: Self.claudeMenuBarQuotaKey)
    }

    func setCompactModeEnabled(_ enabled: Bool) {
        self.compactModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.compactModeEnabledKey)
    }

    func setActivityAnimationsEnabled(_ enabled: Bool) {
        self.activityAnimationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.activityAnimationsEnabledKey)
        if enabled {
            self.startActivityLoopIfNeeded()
        } else if !self.companionEnabled {
            self.activityLoop?.cancel()
            self.activityLoop = nil
            self.providerActivities = Dictionary(uniqueKeysWithValues: self.providers.map {
                ($0.descriptor.id, ProviderActivitySnapshot(
                    providerID: $0.descriptor.id,
                    state: .unknown))
            })
        }
    }

    func setCompanionEnabled(_ enabled: Bool) {
        self.companionEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.companionEnabledKey)
        if enabled {
            self.startActivityLoopIfNeeded()
        } else if !self.activityAnimationsEnabled {
            self.activityLoop?.cancel()
            self.activityLoop = nil
        }
    }

    func setCompanionAnimationIntensity(
        _ intensity: CompanionAnimationIntensity)
    {
        self.companionAnimationIntensity = intensity
        self.companionAnimationsEnabled = intensity.isEnabled
        UserDefaults.standard.set(
            intensity.rawValue,
            forKey: Self.companionAnimationIntensityKey)
        UserDefaults.standard.set(
            intensity.isEnabled,
            forKey: Self.companionAnimationsEnabledKey)
    }

    func setCompanionOverlayEnabled(_ enabled: Bool) {
        self.companionOverlayEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.companionOverlayEnabledKey)
    }

    func setCompanionOverlaySize(_ size: CompanionOverlaySize) {
        self.companionOverlaySize = size
        UserDefaults.standard.set(size.rawValue, forKey: Self.companionOverlaySizeKey)
    }

    func setCompanionOverlayPositionLocked(_ locked: Bool) {
        self.companionOverlayPositionLocked = locked
        UserDefaults.standard.set(
            locked,
            forKey: Self.companionOverlayPositionLockedKey)
    }

    func setCompanionOverlayClickThroughEnabled(_ enabled: Bool) {
        self.companionOverlayClickThroughEnabled = enabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.companionOverlayClickThroughEnabledKey)
    }

    func resetCompanionOverlayPosition() {
        self.companionOverlayPositionResetPulse &+= 1
    }

    func patCompanion() {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        self.companionGameEngine.pat(in: &state)
        self.companionState = state
        self.companionInteractionPulse &+= 1
        self.saveCompanionState()
    }

    func renameCompanion(_ name: String?) {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionState.stage != .egg
        else { return }
        var state = self.companionState
        self.companionGameEngine.rename(name, in: &state)
        self.companionState = state
        self.saveCompanionState()
    }

    func hatchCompanion() {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionCelebration == nil,
              self.companionState.stage == .egg
        else { return }
        var state = self.companionState
        guard let eggID = state.eggs.first?.id,
              let events = try? self.companionGameEngine.openEgg(
                eggID,
                in: &state)
        else { return }
        self.companionState = state
        for event in events {
            if case let .hatched(speciesID, rarity, isNewSpecies, _) = event {
                self.presentCompanionHatch(
                    speciesID: speciesID,
                    rarity: rarity,
                    variantID: state.resolvedVariantID ?? .standard,
                    personalityID: state.personalityID ?? .calm,
                    isNewSpecies: isNewSpecies)
            }
        }
        self.reconcileCompanionRewards()
        self.saveCompanionState()
    }

    func dismissCompanionReveal() {
        self.companionReveal = nil
    }

    func dismissCompanionHatchBatchReveal() {
        self.companionHatchBatchReveal = nil
    }

    func dismissCompanionCelebration() {
        self.companionCelebration = nil
    }

    func dismissCompanionMutationReveal() {
        self.companionMutationReveal = nil
    }

    func synthesizeCompanionMutation(for speciesID: CompanionSpeciesID) {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionCelebration == nil
        else { return }
        let sources = self.companionMutationSources(for: speciesID)
        guard sources.count >= CompanionMutationRegistry.synthesisSourceCount
        else {
            self.companionMutationErrorMessage = AppLocalization.string(
                "companion.mutation.error.sources")
            return
        }

        var state = self.companionState
        do {
            let events = try self.companionGameEngine.synthesizeMutation(
                sourceGenerationIDs: Array(sources.prefix(
                    CompanionMutationRegistry.synthesisSourceCount))
                    .map(\.generationID),
                mutationUnitValue: Double.random(in: 0..<1),
                in: &state)
            self.companionState = state
            self.companionMutationErrorMessage = nil
            for event in events {
                if case let .mutationSynthesized(
                    speciesID,
                    mutationID,
                    consumedGenerationIDs,
                    _,
                    isNewMutation) = event
                {
                    for generationID in consumedGenerationIDs {
                        self.removeCompanionFromPassiveLineup(generationID)
                    }
                    self.companionMutationReveal = CompanionMutationReveal(
                        speciesID: speciesID,
                        mutationID: mutationID,
                        isNewMutation: isNewMutation)
                }
            }
            self.reconcileCompanionRewards()
            self.saveCompanionState()
        } catch let error as CompanionMutationError {
            self.companionMutationErrorMessage = switch error {
            case .requiresThreeSources, .sourceNotFound(_), .sourceIsActive,
                    .sourceSpeciesMismatch, .sourceNotEligible:
                AppLocalization.string("companion.mutation.error.sources")
            case .mutationNotDiscovered:
                AppLocalization.string("companion.mutation.error.unavailable")
            }
        } catch {
            self.companionMutationErrorMessage = AppLocalization.string(
                "companion.mutation.error.unavailable")
        }
    }

    func equipCompanionMutation(_ mutationID: CompanionMutationID?) {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionState.stage != .egg
        else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.equipMutation(
            mutationID,
            in: &state)) != nil
        else {
            self.companionMutationErrorMessage = AppLocalization.string(
                "companion.mutation.error.unavailable")
            return
        }
        self.companionState = state
        self.companionMutationErrorMessage = nil
        self.saveCompanionState()
    }

    func purchaseCompanionEgg(
        _ definitionID: CompanionEggDefinitionID,
        quantity: Int = 1)
    {
        guard self.companionEnabled,
              self.companionStateLoaded,
              !self.companionEconomyTransactionInFlight
        else { return }
        self.companionEconomyErrorMessage = nil
        self.companionEconomyTransactionInFlight = true
        Task {
            defer { self.companionEconomyTransactionInFlight = false }
            do {
                let count = min(max(quantity, 1), 10)
                guard let price = CompanionEggRegistry.definition(
                    for: definitionID)?.price,
                    self.companionRewardState.starShards >= price * count
                else {
                    throw CompanionEggError.insufficientShards(
                        required: (CompanionEggRegistry.definition(
                            for: definitionID)?.price ?? 0) * count,
                        available: self.companionRewardState.starShards)
                }
                for _ in 0..<count {
                    try await self.performCompanionEggPurchase(definitionID)
                }
            } catch {
                self.handleCompanionEconomyFailure(error)
            }
        }
    }

    func openCompanionEgg(_ eggID: UUID) {
        self.openCompanionEggs([eggID])
    }

    func openCompanionEggs(
        definitionID: CompanionEggDefinitionID,
        quantity: Int)
    {
        let eggIDs = self.companionState.eggs
            .filter { $0.definitionID == definitionID }
            .prefix(min(max(quantity, 1), 10))
            .map(\.id)
        self.openCompanionEggs(eggIDs)
    }

    private func openCompanionEggs(_ eggIDs: [UUID]) {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionCelebration == nil,
              !self.companionEconomyTransactionInFlight,
              !eggIDs.isEmpty
        else { return }
        self.companionEconomyErrorMessage = nil
        self.companionEconomyTransactionInFlight = true
        Task {
            defer { self.companionEconomyTransactionInFlight = false }
            var state = self.companionState
            do {
                var reveals: [CompanionHatchReveal] = []
                for eggID in eggIDs {
                    let opensActivePet = state.stage == .egg
                    let events = try self.companionGameEngine.openEgg(
                        eggID,
                        in: &state)
                    if let reveal = self.hatchReveal(
                        from: events,
                        opensActivePet: opensActivePet,
                        state: state)
                    {
                        reveals.append(reveal)
                    }
                }
                self.companionStateSaveRevision &+= 1
                try await self.companionStateStore.save(
                    state,
                    revision: self.companionStateSaveRevision)
                self.companionState = state
                if eggIDs.count == 1, let reveal = reveals.first {
                    self.presentCompanionHatch(reveal)
                } else {
                    self.companionHatchBatchReveal = CompanionHatchBatchReveal(
                        reveals: reveals)
                }
                self.reconcileCompanionRewards()
            } catch {
                self.handleCompanionEconomyFailure(error)
            }
        }
    }

    func sellCompanionEgg(_ eggID: UUID) {
        guard self.companionEnabled,
              self.companionStateLoaded,
              !self.companionEconomyTransactionInFlight
        else { return }
        self.companionEconomyErrorMessage = nil
        self.companionEconomyTransactionInFlight = true
        Task {
            defer { self.companionEconomyTransactionInFlight = false }
            do {
                try await self.performCompanionEggSale(eggID)
            } catch {
                self.handleCompanionEconomyFailure(error)
            }
        }
    }

    func activateCompanion(_ generationID: UUID) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.activateArchivedGeneration(
            generationID,
            in: &state)) != nil
        else { return }
        self.companionState = state
        self.removeCompanionFromPassiveLineup(generationID)
        self.reconcileCompanionRewards()
        self.saveCompanionState()
    }

    func selectCompanionGrowthTarget(_ generationID: UUID) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.selectGrowthTarget(
            generationID,
            in: &state)) != nil
        else { return }
        self.companionState = state
        self.saveCompanionState()
    }

    func sellCompanion(_ generationID: UUID) {
        guard self.companionEnabled,
              self.companionStateLoaded,
              !self.companionEconomyTransactionInFlight
        else { return }
        self.companionEconomyErrorMessage = nil
        self.companionEconomyTransactionInFlight = true
        Task {
            defer { self.companionEconomyTransactionInFlight = false }
            do {
                try await self.performCompanionSale(generationID)
                self.removeCompanionFromPassiveLineup(generationID)
            } catch {
                self.handleCompanionEconomyFailure(error)
            }
        }
    }

    private func performCompanionEggPurchase(
        _ definitionID: CompanionEggDefinitionID) async throws
    {
        guard let definition = CompanionEggRegistry.definition(
            for: definitionID),
            let price = definition.price
        else { throw CompanionEggError.eggNotPurchasable }
        guard CompanionEggRegistry.isUnlocked(
            definition,
            highestPetLevel: self.companionState.highestPetLevel,
            discoveredSpeciesCount:
                self.companionState.collection.discoveredSpeciesIDs.count)
        else { throw CompanionEggError.eggLocked }

        let transaction = CompanionEconomyTransaction(kind: .purchaseEgg(
            definitionID: definitionID,
            seed: UInt64.random(in: 0...UInt64(Int64.max)),
            price: price))
        var companion = self.companionState
        var rewards = self.companionRewardState
        try self.applyCompanionEconomyTransaction(
            transaction,
            companion: &companion,
            rewards: &rewards)
        try await self.commitCompanionEconomyTransaction(
            transaction,
            companion: companion,
            rewards: rewards)
    }

    private func performCompanionEggSale(_ eggID: UUID) async throws {
        guard let egg = self.companionState.eggs.first(where: {
            $0.id == eggID
        }),
        let definition = CompanionEggRegistry.definition(
            for: egg.definitionID),
        definition.isSellable
        else { throw CompanionEggError.eggNotSellable }

        let transaction = CompanionEconomyTransaction(kind: .sellEgg(
            eggID: eggID,
            value: definition.resaleValue))
        var companion = self.companionState
        var rewards = self.companionRewardState
        try self.applyCompanionEconomyTransaction(
            transaction,
            companion: &companion,
            rewards: &rewards)
        try await self.commitCompanionEconomyTransaction(
            transaction,
            companion: companion,
            rewards: rewards)
    }

    private func performCompanionSale(_ generationID: UUID) async throws {
        guard let companionToSell = self.companionState.collection
            .archivedGenerations.first(where: {
                $0.generationID == generationID
            })
        else { throw CompanionGameError.archivedGenerationNotFound }
        let variantID = companionToSell.variantID
            ?? CompanionVariantRegistry.migrated(
                from: companionToSell.finalRarity)
        let transaction = CompanionEconomyTransaction(kind: .sellPet(
            generationID: generationID,
            value: variantID == .prismatic ? 60 : 30))
        var companion = self.companionState
        var rewards = self.companionRewardState
        try self.applyCompanionEconomyTransaction(
            transaction,
            companion: &companion,
            rewards: &rewards)
        try await self.commitCompanionEconomyTransaction(
            transaction,
            companion: companion,
            rewards: rewards)
    }

    private func applyCompanionEconomyTransaction(
        _ transaction: CompanionEconomyTransaction,
        companion: inout CompanionGameState,
        rewards: inout CompanionRewardState) throws
    {
        switch transaction.kind {
        case let .purchaseEgg(definitionID, seed, price):
            try self.companionRewardEngine.spendStarShards(
                price,
                transactionID: transaction.id,
                at: transaction.createdAt,
                in: &rewards)
            _ = try self.companionGameEngine.acquireEgg(
                definitionID: definitionID,
                seed: seed,
                source: .shop,
                transactionID: transaction.id,
                at: transaction.createdAt,
                in: &companion)
        case let .sellEgg(eggID, value):
            _ = try self.companionGameEngine.sellEgg(
                eggID,
                transactionID: transaction.id,
                at: transaction.createdAt,
                in: &companion)
            self.companionRewardEngine.grantStarShards(
                value,
                transactionID: transaction.id,
                at: transaction.createdAt,
                in: &rewards)
        case let .sellPet(generationID, value):
            _ = try self.companionGameEngine.sellArchivedGeneration(
                generationID,
                transactionID: transaction.id,
                at: transaction.createdAt,
                in: &companion)
            self.companionRewardEngine.grantStarShards(
                value,
                transactionID: transaction.id,
                at: transaction.createdAt,
                in: &rewards)
        }
    }

    private func commitCompanionEconomyTransaction(
        _ transaction: CompanionEconomyTransaction,
        companion: CompanionGameState,
        rewards: CompanionRewardState) async throws
    {
        try await self.companionEconomyTransactionStore.begin(transaction)
        self.companionStateSaveRevision &+= 1
        try await self.companionStateStore.save(
            companion,
            revision: self.companionStateSaveRevision)
        self.companionRewardSaveRevision &+= 1
        try await self.companionRewardStateStore.save(
            rewards,
            revision: self.companionRewardSaveRevision)
        try await self.companionEconomyTransactionStore.complete(
            transaction.id)
        self.companionState = companion
        self.companionRewardState = rewards
    }

    private func recoverCompanionEconomyTransactions(
        _ journal: CompanionEconomyTransactionJournal) async throws
    {
        for transaction in journal.pending {
            var companion = self.companionState
            var rewards = self.companionRewardState
            try self.applyCompanionEconomyTransaction(
                transaction,
                companion: &companion,
                rewards: &rewards)
            self.companionStateSaveRevision &+= 1
            try await self.companionStateStore.save(
                companion,
                revision: self.companionStateSaveRevision)
            self.companionRewardSaveRevision &+= 1
            try await self.companionRewardStateStore.save(
                rewards,
                revision: self.companionRewardSaveRevision)
            try await self.companionEconomyTransactionStore.complete(
                transaction.id)
            self.companionState = companion
            self.companionRewardState = rewards
        }
    }

    private func handleCompanionEconomyFailure(_ error: any Error) {
        if let eggError = error as? CompanionEggError {
            switch eggError {
            case .eggLocked:
                self.companionEconomyErrorMessage = AppLocalization.string(
                    "companion.economy.error.locked")
            case .insufficientShards:
                self.companionEconomyErrorMessage = AppLocalization.string(
                    "companion.economy.error.insufficient")
            case .lastPetCannotBeSold, .activePetCannotBeSold:
                self.companionEconomyErrorMessage = AppLocalization.string(
                    "companion.economy.error.lastPet")
            default:
                self.companionEconomyErrorMessage = AppLocalization.string(
                    "companion.economy.error.changed")
            }
            return
        }
        if let rewardError = error as? CompanionRewardError {
            self.companionEconomyErrorMessage = AppLocalization.string(
                rewardError == .insufficientStarShards
                    ? "companion.economy.error.insufficient"
                    : "companion.economy.error.changed")
            return
        }
        if error is CompanionGameError {
            self.companionEconomyErrorMessage = AppLocalization.string(
                "companion.economy.error.changed")
            return
        }
        self.companionDataUnavailable = true
        self.companionStateLoaded = false
    }

    private func removeCompanionFromPassiveLineup(_ generationID: UUID) {
        var benefit = self.companionBenefitState
        var changed = false
        for index in benefit.passiveGenerationIDs.indices
            where benefit.passiveGenerationIDs[index] == generationID
        {
            benefit.passiveGenerationIDs[index] = nil
            changed = true
        }
        guard changed else { return }
        benefit.updatedAt = .now
        self.companionBenefitState = benefit
        self.saveCompanionBenefitState()
    }

    func evolveCompanion() {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionCelebration == nil,
              !self.isCompanionEvolving,
              self.companionState.stage == .hatchling
                || self.companionState.stage == .junior
        else { return }
        let fromStage = self.companionState.stage
        var state = self.companionState
        guard (try? self.companionGameEngine.evolve(
            unitValue: Double.random(in: 0..<1),
            in: &state)) != nil
        else { return }
        self.companionState = state
        self.presentCompanionEvolution(from: fromStage, state: state)
        if self.companionAnimationsEnabled,
           !ProcessInfo.processInfo.isLowPowerModeEnabled,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        {
            self.isCompanionEvolving = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.4))
                self?.isCompanionEvolving = false
            }
        }
        self.reconcileCompanionRewards()
        self.saveCompanionState()
    }

    func showcaseArchivedCompanion(_ generationID: UUID?) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.showcaseArchivedGeneration(
            generationID,
            in: &state)) != nil
        else { return }
        self.companionState = state
        self.saveCompanionState()
    }

    func setPassiveCompanion(_ generationID: UUID?, slot: Int) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionBenefitState
        do {
            try self.companionBenefitEngine.assignPassive(
                generationID: generationID,
                to: slot,
                archivedCompanions:
                    self.companionState.collection.archivedGenerations,
                in: &state)
            self.companionBenefitState = state
            self.companionBenefitError = nil
            self.saveCompanionBenefitState()
        } catch let error as CompanionBenefitError {
            self.companionBenefitError = error
        } catch {
            self.companionBenefitError = .archivedCompanionNotFound
        }
    }

    private func recordAutomaticCompanionAttendance(at date: Date) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionRewardState
        guard self.companionRewardEngine.attendanceStatus(
            at: date,
            in: state) == .available
        else { return }
        do {
            let grants = try self.companionRewardEngine.checkIn(
                at: date,
                in: &state)
            self.companionRewardState = state
            self.companionRewardNoticeAmount = grants.reduce(0) { $0 + $1.amount }
            self.companionAttendanceError = nil
            self.saveCompanionRewardState()
        } catch let error as CompanionRewardError {
            self.companionRewardNoticeAmount = nil
            self.companionAttendanceError = error
        } catch {
            self.companionRewardNoticeAmount = nil
        }
    }

    func purchaseCompanionCosmetic(_ cosmeticID: CompanionCosmeticID) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionRewardState
        guard (try? self.companionRewardEngine.purchase(
            cosmeticID: cosmeticID,
            in: &state)) != nil
        else { return }
        self.companionRewardState = state
        self.saveCompanionRewardState()
    }

    func selectCompanionCosmetic(_ cosmeticID: CompanionCosmeticID) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionRewardState
        guard (try? self.companionRewardEngine.select(
            cosmeticID: cosmeticID,
            in: &state)) != nil
        else { return }
        self.companionRewardState = state
        self.saveCompanionRewardState()
    }

    func unequipCompanionCosmetic(slot: CompanionCosmeticSlot) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionRewardState
        self.companionRewardEngine.unequip(slot: slot, in: &state)
        self.companionRewardState = state
        self.saveCompanionRewardState()
    }

    func activateCompanionEnergyBooster(_ boosterID: CompanionEnergyBoosterID) {
        var state = self.companionRewardState
        guard (try? self.companionRewardEngine.activateEnergyBooster(
            boosterID,
            in: &state)) != nil
        else { return }
        self.companionRewardState = state
        self.saveCompanionRewardState()
    }

    func purchaseCompanionEnergyBooster(_ boosterID: CompanionEnergyBoosterID) {
        var state = self.companionRewardState
        guard (try? self.companionRewardEngine.purchaseEnergyBooster(
            boosterID,
            in: &state)) != nil
        else { return }
        self.companionRewardState = state
        self.saveCompanionRewardState()
    }

    func setActivityWindowSeconds(_ seconds: Int) {
        guard Self.supportedActivityWindows.contains(seconds) else { return }
        self.activityWindowSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: Self.activityWindowSecondsKey)
        Task { await self.refreshActivity() }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try self.launchAtLoginController.setEnabled(enabled)
            self.launchAtLoginEnabled = self.launchAtLoginController.isEnabled
            self.launchAtLoginMessage = self.launchAtLoginController.statusMessage
        } catch {
            self.launchAtLoginEnabled = self.launchAtLoginController.isEnabled
            self.launchAtLoginMessage = error.localizedDescription
        }
    }

    var menuBarRemainingPercent: Double? {
        return UsageSummary.minimumRemainingPercent(in: self.snapshots)
    }

    var selectedMenuBarProvider: ProviderDescriptor? {
        self.descriptors.first { $0.id == self.selectedMenuBarProviderID }
    }

    var selectedMenuBarProviderRemainingPercent: Double? {
        if self.selectedMenuBarProviderID == .claude {
            return UsageSummary.remainingPercent(
                in: self.snapshots,
                for: .claude,
                windowID: self.claudeMenuBarQuota.windowID)
        }
        return UsageSummary.minimumRemainingPercent(
            in: self.snapshots,
            for: self.selectedMenuBarProviderID)
    }

    var menuBarMonthlyCost: String? {
        self.costDisplayCurrency.formatted(
            amountUSD: self.monthlyEstimatedSpendUSD,
            exchangeRate: self.exchangeRateQuote)
    }

    var descriptors: [ProviderDescriptor] {
        self.providers.map(\.descriptor)
    }

    var authorizationDescriptors: [ProviderDescriptor] {
        self.providers.compactMap { provider in
            guard provider is any UsageAuthorizationProviding else { return nil }
            return provider.descriptor
        }
    }

    var hasActiveSession: Bool {
        self.providerActivities.values.contains { $0.state == .active }
    }

    var showsActiveSession: Bool {
        self.activityAnimationsEnabled && self.hasActiveSession
    }

    var companionStage: CompanionGameStage {
        self.companionState.stage
    }

    var showcasedCompanion: CompletedCompanionGeneration? {
        self.companionState.showcasedGeneration
    }

    var isShowingArchivedCompanion: Bool {
        self.showcasedCompanion != nil
    }

    var displayedCompanionSpeciesID: CompanionSpeciesID? {
        self.showcasedCompanion?.speciesID ?? self.companionState.speciesID
    }

    var displayedCompanionStage: CompanionGameStage {
        self.showcasedCompanion?.stage ?? self.companionStage
    }

    var displayedCompanionRarity: CompanionRarity? {
        if self.companionRewardState.selectedCosmeticIDs.contains(
            .azurePalette)
        {
            return .rare
        }
        if self.companionRewardState.selectedCosmeticIDs.contains(
            .violetPalette)
        {
            return .epic
        }
        return self.showcasedCompanion?.finalRarity
            ?? self.companionState.rarity
    }

    var displayedCompanionVariantID: CompanionVariantID? {
        if let showcased = self.showcasedCompanion {
            return showcased.variantID
                ?? CompanionVariantRegistry.migrated(
                    from: showcased.finalRarity)
        }
        return self.companionState.resolvedVariantID
    }

    var displayedCompanionMutationID: CompanionMutationID? {
        if let showcased = self.showcasedCompanion {
            return showcased.mutationID
        }
        return self.companionState.activeMutationID
    }

    var companionMutationRecords: [CompanionMutationRecord] {
        self.companionState.collection.mutations.sorted {
            if $0.speciesID != $1.speciesID {
                return $0.speciesID.rawValue < $1.speciesID.rawValue
            }
            return $0.mutationID.rawValue < $1.mutationID.rawValue
        }
    }

    var companionMutationReadySpecies: [CompanionSpeciesID] {
        CompanionSpeciesID.allCases.filter {
            self.companionMutationSources(for: $0).count
                >= CompanionMutationRegistry.synthesisSourceCount
        }
    }

    func companionMutationSources(
        for speciesID: CompanionSpeciesID) -> [CompletedCompanionGeneration]
    {
        self.companionState.collection.archivedGenerations
            .filter {
                $0.speciesID == speciesID
                    && CompanionMutationRegistry.isEligibleSource($0)
            }
            .sorted {
                if $0.generationNumber != $1.generationNumber {
                    return $0.generationNumber < $1.generationNumber
                }
                return $0.completedAt < $1.completedAt
            }
    }

    var displayedCompanionNickname: String? {
        self.showcasedCompanion?.nickname ?? self.companionState.nickname
    }

    var displayedCompanionPersonalityID: CompanionPersonalityID? {
        self.showcasedCompanion?.personalityID
            ?? self.companionState.personalityID
    }

    var displayedCompanionLevel: Int {
        self.showcasedCompanion.map {
            CompanionLevelCurve.standard.level(forXP: $0.growthXP)
        } ?? self.companionState.level
    }

    var companionLevel: Int { self.companionState.level }

    var companionXPIntoLevel: Int {
        CompanionLevelCurve.standard.xpIntoLevel(
            forXP: self.companionState.growthXP)
    }

    var companionNextLevelXP: Int {
        CompanionLevelCurve.standard.xpToNextLevel(
            from: max(self.companionState.level, 1))
    }

    var companionNextEvolutionLevel: Int? {
        self.companionState.nextEvolution?.requiredLevel
    }

    var companionNextRecurringRewardLevel: Int {
        CompanionRewardEngine.nextRecurringRewardLevel(
            after: self.companionState.level)
    }

    var activeBenefitCompanion: CompanionBenefitCompanion? {
        if let showcased = self.showcasedCompanion {
            return CompanionBenefitCompanion(
                generationID: showcased.generationID,
                speciesID: showcased.speciesID,
                rarity: showcased.finalRarity)
        }
        guard self.companionState.stage != .egg,
              let speciesID = self.companionState.speciesID,
              let rarity = self.companionState.rarity
        else { return nil }
        return CompanionBenefitCompanion(
            generationID: self.companionState.generationID,
            speciesID: speciesID,
            rarity: rarity)
    }

    var activeCompanionBenefitDefinition: CompanionBenefitDefinition? {
        guard let companion = self.activeBenefitCompanion,
              let definition = CompanionBenefitRegistry.definition(
                for: companion.speciesID),
              definition.activation == .active
        else { return nil }
        return definition
    }

    var displayedCompanionBenefitDefinition: CompanionBenefitDefinition? {
        guard let speciesID = self.displayedCompanionSpeciesID else {
            return nil
        }
        return CompanionBenefitRegistry.definition(for: speciesID)
    }

    var activeCompanionBenefitProgress: CompanionBenefitProgress? {
        guard let generationID = self.activeBenefitCompanion?.generationID else {
            return nil
        }
        return self.companionBenefitState.progress.first {
            $0.generationID == generationID
        }
    }

    var companionActivePassives: [CompanionBenefitCompanion] {
        self.companionBenefitEngine.activePassives(
            archivedCompanions: self.companionState.collection.archivedGenerations,
            state: self.companionBenefitState)
    }

    var companionUnlockedPassiveSlotCount: Int {
        self.companionBenefitState.unlockedPassiveSlotCount
    }

    var companionPassiveAssignments: [CompletedCompanionGeneration?] {
        let archived = Dictionary(uniqueKeysWithValues:
            self.companionState.collection.archivedGenerations.map {
                ($0.generationID, $0)
            })
        return (0..<5).map { index in
            guard index < self.companionBenefitState.passiveGenerationIDs.count,
                  let generationID =
                    self.companionBenefitState.passiveGenerationIDs[index]
            else { return nil }
            return archived[generationID]
        }
    }

    func companionPassiveSlot(for generationID: UUID) -> Int? {
        self.companionBenefitState.passiveGenerationIDs.firstIndex {
            $0 == generationID
        }
    }

    var companionPassiveCandidates: [CompletedCompanionGeneration] {
        self.companionState.collection.archivedGenerations.filter {
            CompanionBenefitRegistry.definition(for: $0.speciesID)?
                .activation == .passive
        }
    }

    var companionNextPassiveSlotThreshold: Int? {
        self.companionBenefitEngine.passiveSlotThresholds.first {
            self.companionState.collection.unlockedFormCount < $0
        }
    }

    func companionPassiveUnlockThreshold(for slot: Int) -> Int? {
        guard slot > 0,
              slot - 1 < self.companionBenefitEngine.passiveSlotThresholds.count
        else { return nil }
        return self.companionBenefitEngine.passiveSlotThresholds[slot - 1]
    }

    var companionBehavior: CompanionBehavior {
        CompanionBehaviorResolver.resolve(
            state: self.companionState,
            isWorking: self.hasActiveSession,
            lowestRemainingQuotaPercent: self.menuBarRemainingPercent)
    }

    var companionStageProgress: Double {
        CompanionLevelCurve.standard.progress(
            forXP: self.companionState.growthXP)
    }

    var companionPrismaticPityHatches: Int {
        self.companionGameEngine.rules.prismaticPityHatches
    }

    var companionPrismaticChancePercent: Int {
        Int((self.companionGameEngine.rules.prismaticChance * 100).rounded())
    }

    var canPerformCompanionAction: Bool {
        self.companionStateLoaded
            && self.companionCelebration == nil
            && !self.isCompanionEvolving
            && self.companionGameEngine.canPerformAction(
                for: self.companionState)
    }

    private var canPresentCompanionCelebration: Bool {
        self.companionAnimationsEnabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func presentCompanionHatch(
        speciesID: CompanionSpeciesID,
        rarity: CompanionRarity,
        variantID: CompanionVariantID,
        personalityID: CompanionPersonalityID,
        isNewSpecies: Bool)
    {
        let reveal = CompanionHatchReveal(
            speciesID: speciesID,
            rarity: rarity,
            variantID: variantID,
            personalityID: personalityID,
            isNewSpecies: isNewSpecies)
        self.presentCompanionHatch(reveal)
    }

    private func presentCompanionHatch(_ reveal: CompanionHatchReveal) {
        guard self.canPresentCompanionCelebration else {
            self.companionReveal = reveal
            return
        }
        self.companionReveal = nil
        self.companionCelebration = CompanionCelebration(
            kind: .hatch,
            speciesID: reveal.speciesID,
            stage: .hatchling,
            rarity: reveal.rarity,
            variantID: reveal.variantID,
            personalityID: reveal.personalityID,
            isNewSpecies: reveal.isNewSpecies)
    }

    private func hatchReveal(
        from events: [CompanionGameEvent],
        opensActivePet: Bool,
        state: CompanionGameState) -> CompanionHatchReveal?
    {
        guard let hatch = events.first(where: {
            if case .hatched = $0 { return true }
            return false
        }),
        case let .hatched(speciesID, rarity, isNewSpecies, _) = hatch
        else { return nil }
        let duplicateTargetID = events.compactMap { event -> UUID? in
            if case let .duplicateConverted(generationID, _) = event {
                return generationID
            }
            return nil
        }.first
        let duplicateTarget = duplicateTargetID.flatMap { generationID in
            state.collection.archivedGenerations.first {
                $0.generationID == generationID
            }
        }
        let latest = duplicateTarget
            ?? state.collection.recentCompletedGenerations.last
        let duplicateIsActive = duplicateTargetID == state.generationID
        return CompanionHatchReveal(
            speciesID: speciesID,
            rarity: rarity,
            variantID: (opensActivePet || duplicateIsActive
                ? state.resolvedVariantID
                : latest?.variantID) ?? .standard,
            personalityID: (opensActivePet || duplicateIsActive
                ? state.personalityID
                : latest?.personalityID) ?? .calm,
            isNewSpecies: isNewSpecies)
    }

    private func presentCompanionEvolution(
        from fromStage: CompanionGameStage,
        state: CompanionGameState)
    {
        guard self.canPresentCompanionCelebration,
              let speciesID = state.speciesID
        else { return }
        self.companionCelebration = CompanionCelebration(
            kind: .evolution,
            speciesID: speciesID,
            stage: state.stage,
            rarity: state.rarity ?? .normal,
            variantID: state.resolvedVariantID ?? .standard,
            personalityID: state.personalityID ?? .calm,
            fromStage: fromStage)
    }

    var hasReadyCompanionGrowthAction: Bool {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionStage == .egg
                || self.companionStage == .hatchling
                || self.companionStage == .junior
        else {
            return false
        }
        return self.canPerformCompanionAction
    }

    var showsCompanionOverlay: Bool {
        self.companionEnabled
            && self.companionOverlayEnabled
            && !self.companionDataUnavailable
    }

    var companionTodayEnergy: Int {
        self.companionState.growthEarnedToday
    }

    var companionTodayTokens: Int64 {
        let dateKey = GrowthLocalDate.key(for: .now)
        return self.tokenGrowthLedgerState.dayCredits
            .first { $0.dateKey == dateKey }?
            .aggregateTokens ?? 0
    }

    var companionTodayEnergyTarget: Int {
        let dateKey = GrowthLocalDate.key(for: .now)
        return self.tokenGrowthLedgerState.dayCredits
            .first { $0.dateKey == dateKey }?
            .targetEnergy ?? 0
    }

    var companionNextEnergyTokenRequirement: Int64? {
        TokenGrowthEnergyFormula.standard.additionalTokensForNextEnergy(
            afterDailyTokens: self.tokenGrowthLedgerState.conversionRemainderTokens)
    }

    var companionGrowthProviderBreakdown: [CompanionGrowthProviderBreakdown] {
        let dateKey = GrowthLocalDate.key(for: .now)
        let totals = self.tokenGrowthLedgerState.providerDayTotals
            .filter { $0.dateKey <= dateKey }
            .reduce(into: [ProviderID: GrowthProviderDayTotal]()) { result, total in
                guard let existing = result[total.providerID] else {
                    result[total.providerID] = total
                    return
                }
                if total.dateKey > existing.dateKey
                    || (total.dateKey == existing.dateKey && total.tokens > existing.tokens)
                {
                    result[total.providerID] = total
                }
            }

        return self.providers
            .filter {
                $0.descriptor.capabilities.supportsTokenUsage
                    && (self.enabledProviderIDs.contains($0.descriptor.id)
                        || totals[$0.descriptor.id] != nil)
            }
            .map { provider in
                let snapshot = self.snapshots.first {
                    $0.id == provider.descriptor.id
                }
                let total = totals[provider.descriptor.id]
                let creditedDateKey = total?.lastCreditedAt.map {
                    GrowthLocalDate.key(for: $0)
                }
                return CompanionGrowthProviderBreakdown(
                    descriptor: provider.descriptor,
                    reflectedTokens: total?.tokens,
                    usageDateKey: total?.dateKey,
                    wasSettledToday: total?.dateKey != dateKey
                        && creditedDateKey == dateKey,
                    isTodayPending: snapshot?.accountTokenUsage.map {
                        $0.todayTokens == nil
                    } ?? false,
                    accountIssue: snapshot?.accountTokenUsageIssue)
            }
    }

    var companionAttendanceStatus: CompanionAttendanceStatus {
        self.companionRewardEngine.attendanceStatus(in: self.companionRewardState)
    }

    var companionAttendanceWeekCount: Int {
        self.companionRewardEngine.attendanceCountThisWeek(
            in: self.companionRewardState)
    }

    var companionAttendanceMonthCount: Int {
        self.companionRewardEngine.attendanceCountThisMonth(
            in: self.companionRewardState)
    }

    var companionAttendanceWeeklyGoal: Int {
        self.companionRewardEngine.rules.weeklyAttendance.keys.max() ?? 7
    }

    var companionAttendanceMonthlyGoal: Int {
        self.companionRewardEngine.rules.monthlyAttendanceDays
    }

    var companionCosmetics: [CompanionCosmetic] {
        self.companionRewardEngine.cosmetics
    }

    var companionActiveEnergyBooster: CompanionActiveEnergyBooster? {
        guard let booster = self.companionRewardState.activeEnergyBooster,
              booster.isActive(at: .now)
        else { return nil }
        return booster
    }

    var companionGrowthProviderStatus: (available: Int, total: Int) {
        let enabled = self.snapshots.filter {
            $0.availability == .available
                && $0.descriptor.capabilities.supportsTokenUsage
        }
        return (
            enabled.filter { $0.growthUsageObservation != nil }.count,
            enabled.count)
    }

    func isActive(_ providerID: ProviderID) -> Bool {
        self.providerActivities[providerID]?.state == .active
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
    }

    var monthlyEstimatedSpendUSD: Double {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start
            ?? .distantPast
        let recordedProviderSpend = UsageCostSummary.accumulatedUSD(
            in: self.historyRecords.filter { $0.providerID != .codex },
            since: startOfMonth)
        let codexAccountReference = self.snapshots.first(where: { $0.id == .codex })?
            .costEstimate?.amountUSD ?? 0
        return recordedProviderSpend + codexAccountReference
    }

    var monthlyBudgetUSD: Double? {
        guard self.monthlyBudgetEnabled, self.monthlyBudgetAmount > 0 else { return nil }
        return self.monthlyBudgetCurrency.usdAmount(
            from: self.monthlyBudgetAmount,
            exchangeRate: self.exchangeRateQuote)
    }

    private func processBudgetAlert() {
        guard let budgetUSD = self.monthlyBudgetUSD,
              budgetUSD > 0,
              let spent = self.costDisplayCurrency.formatted(
                  amountUSD: self.monthlyEstimatedSpendUSD,
                  exchangeRate: self.exchangeRateQuote),
              let budget = self.costDisplayCurrency.formatted(
                  amountUSD: budgetUSD,
                  exchangeRate: self.exchangeRateQuote)
        else { return }
        self.notificationController.processBudget(
            spentUSD: self.monthlyEstimatedSpendUSD,
            budgetUSD: budgetUSD,
            spentText: spent,
            budgetText: budget,
            enabled: self.budgetNotificationsEnabled,
            preferences: self.notificationPreferences)
    }

    private var notificationPreferences: UsageNotificationPreferences {
        UsageNotificationPreferences(
            lowUsageEnabled: self.lowUsageNotificationsEnabled,
            resetEnabled: self.resetNotificationsEnabled,
            connectionIssuesEnabled: self.connectionIssueNotificationsEnabled,
            quietHoursEnabled: self.notificationQuietHoursEnabled,
            quietHoursStart: self.notificationQuietHoursStart,
            quietHoursEnd: self.notificationQuietHoursEnd)
    }

    private func startActivityLoopIfNeeded() {
        guard self.activityAnimationsEnabled || self.companionEnabled,
              self.activityLoop == nil
        else { return }
        self.activityLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshActivity()
                try? await Task.sleep(for: Self.activityRefreshInterval)
            }
        }
    }

    private func refreshActivity() async {
        guard self.activityAnimationsEnabled || self.companionEnabled else { return }
        let now = Date.now
        let activeWindow = TimeInterval(self.activityWindowSeconds)
        let cutoff = now.addingTimeInterval(-activeWindow)
        let enabledIDs = self.enabledProviderIDs
        let activeProviders = self.providers.filter { enabledIDs.contains($0.descriptor.id) }
        let results = await withTaskGroup(
            of: ProviderActivitySnapshot.self,
            returning: [ProviderActivitySnapshot].self)
        { group in
            for provider in activeProviders {
                guard let activityProvider = provider as? any UsageActivityProviding else {
                    group.addTask {
                        ProviderActivitySnapshot(
                            providerID: provider.descriptor.id,
                            state: .unknown)
                    }
                    continue
                }
                group.addTask {
                    ProviderActivityEvaluator.snapshot(
                        providerID: activityProvider.descriptor.id,
                        lastActivityAt: activityProvider.latestActivityDate(since: cutoff),
                        now: now,
                        activeWindow: activeWindow)
                }
            }
            var snapshots: [ProviderActivitySnapshot] = []
            for await snapshot in group {
                snapshots.append(snapshot)
            }
            return snapshots
        }
        self.providerActivities = Dictionary(uniqueKeysWithValues: results.map {
            ($0.providerID, $0)
        })
        if self.showsActiveSession {
            self.activityAnimationPulse &+= 1
        }
        self.recordCompanionActivity(at: now)
    }

    private func recordCompanionActivity(at now: Date) {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        let previousState = self.companionState
        var state = previousState
        self.companionGameEngine.rollOverEnergyIfNeeded(
            at: now,
            in: &state)
        self.companionGameEngine.recordActivity(
            isActive: self.hasActiveSession,
            at: now,
            in: &state)
        guard state != previousState else { return }
        self.companionState = state
        let didRollOver = state.growthDateKey != previousState.growthDateKey
        let shouldPersistActivity = self.hasActiveSession
            && self.lastCompanionActivityPersistenceAt.map {
                now.timeIntervalSince($0)
                    >= Self.companionActivityPersistenceInterval
            } != false
        guard didRollOver || shouldPersistActivity else { return }
        self.lastCompanionActivityPersistenceAt = now
        self.saveCompanionState()
    }

    private func processCompanionGrowth(at now: Date) async {
        guard self.companionEnabled,
              self.companionStateLoaded,
              !self.companionGrowthDataUnavailable
        else { return }
        var ledger = self.tokenGrowthLedgerState
        _ = self.tokenGrowthLedgerEngine.process(
            observations: self.snapshots.compactMap(\.growthUsageObservation),
            at: now,
            in: &ledger)
        do {
            self.tokenGrowthLedgerSaveRevision &+= 1
            try await self.tokenGrowthLedgerStore.save(
                ledger,
                revision: self.tokenGrowthLedgerSaveRevision)
            self.tokenGrowthLedgerState = ledger
        } catch {
            return
        }
        await self.applyPendingCompanionGrowthAwards()
    }

    private func applyPendingCompanionGrowthAwards() async {
        guard self.companionStateLoaded else { return }
        for award in self.tokenGrowthLedgerState.pendingAwards {
            var companion = self.companionState
            let multiplier = self.companionRewardEngine.energyMultiplier(
                at: award.createdAt,
                in: self.companionRewardState)
            let (boostedEnergy, overflow) = award.energy
                .multipliedReportingOverflow(by: multiplier)
            let effectiveAward = GrowthEnergyAward(
                id: award.id,
                dateKey: award.dateKey,
                energy: overflow ? Int.max : boostedEnergy,
                createdAt: award.createdAt)
            let events: [CompanionGameEvent]
            do {
                events = self.companionGameEngine.apply(
                    award: effectiveAward,
                    bondEnergy: award.energy,
                    to: &companion)
                self.companionStateSaveRevision &+= 1
                try await self.companionStateStore.save(
                    companion,
                    revision: self.companionStateSaveRevision)
            } catch {
                return
            }
            self.companionState = companion
            var rewards = self.companionRewardState
            if let targetID = companion.resolvedGrowthTargetGenerationID {
                self.companionRewardEngine.reconcileLevelMilestones(
                    generationID: targetID,
                    level: companion.growthTargetLevel,
                    at: award.createdAt,
                    in: &rewards)
            }
            if rewards != self.companionRewardState {
                let shardIncrease = max(
                    rewards.starShards
                        - self.companionRewardState.starShards,
                    0)
                self.companionRewardState = rewards
                if shardIncrease > 0 {
                    self.companionRewardNoticeAmount = shardIncrease
                }
                self.saveCompanionRewardState()
            }
            self.recordAutomaticCompanionAttendance(at: award.createdAt)
            if events.contains(where: { event in
                if case let .energyApplied(amount) = event {
                    return amount > 0
                }
                return false
            }) {
                self.companionGrowthPulse &+= 1
                self.reconcileCompanionRewards()
            }

            var ledger = self.tokenGrowthLedgerState
            self.tokenGrowthLedgerEngine.markApplied(award.id, in: &ledger)
            do {
                self.tokenGrowthLedgerSaveRevision &+= 1
                try await self.tokenGrowthLedgerStore.save(
                    ledger,
                    revision: self.tokenGrowthLedgerSaveRevision)
                self.tokenGrowthLedgerState = ledger
            } catch {
                return
            }
        }
    }

    private func applyPendingCompanionBenefitEnergy() async {
        for bonus in self.companionBenefitState.pendingEnergyBonuses {
            var companion = self.companionState
            let dateKey = GrowthLocalDate.key(for: bonus.createdAt)
            let events = self.companionGameEngine.apply(
                award: GrowthEnergyAward(
                    id: bonus.id,
                    dateKey: dateKey,
                    energy: bonus.amount,
                    createdAt: bonus.createdAt),
                to: &companion)
            do {
                self.companionStateSaveRevision &+= 1
                try await self.companionStateStore.save(
                    companion,
                    revision: self.companionStateSaveRevision)
            } catch {
                return
            }
            self.companionState = companion
            if events.contains(where: {
                if case let .energyApplied(amount) = $0 { return amount > 0 }
                return false
            }) {
                self.companionGrowthPulse &+= 1
                self.reconcileCompanionRewards()
            }

            var benefit = self.companionBenefitState
            self.companionBenefitEngine.markEnergyBonusApplied(
                bonus.id,
                in: &benefit)
            do {
                self.companionBenefitSaveRevision &+= 1
                try await self.companionBenefitStateStore.save(
                    benefit,
                    revision: self.companionBenefitSaveRevision)
                self.companionBenefitState = benefit
            } catch {
                return
            }
        }
    }

    private func saveCompanionState() {
        let state = self.companionState
        self.companionStateSaveRevision &+= 1
        let revision = self.companionStateSaveRevision
        Task {
            try? await self.companionStateStore.save(state, revision: revision)
        }
    }

    private func saveCompanionBenefitState() {
        let state = self.companionBenefitState
        self.companionBenefitSaveRevision &+= 1
        let revision = self.companionBenefitSaveRevision
        Task {
            try? await self.companionBenefitStateStore.save(
                state,
                revision: revision)
        }
    }

    private func settleCompanionTimeBenefits(at date: Date) {
        var benefit = self.companionBenefitState
        let shards = self.companionBenefitEngine.settleActiveTime(
            activeCompanion: self.activeBenefitCompanion,
            at: date,
            in: &benefit)
        guard benefit != self.companionBenefitState || shards > 0 else { return }
        self.companionBenefitState = benefit
        self.saveCompanionBenefitState()
        guard shards > 0 else { return }
        var reward = self.companionRewardState
        guard self.companionRewardEngine.grantBenefitShards(
            shards,
            benefitID: .starlightCache,
            at: date,
            in: &reward) != nil
        else { return }
        self.companionRewardState = reward
        self.companionRewardNoticeAmount = shards
        self.saveCompanionRewardState()
    }

    private func reconcileCompanionRewards() {
        self.reconcileLegacyCompanionPalettes()
        var state = self.companionRewardState
        _ = self.companionRewardEngine.reconcile(
            collection: self.companionState.collection,
            in: &state)
        _ = self.companionRewardEngine.rewardVerifiedGrowth(
            energy: self.companionState.growthEarnedToday,
            in: &state)
        _ = self.companionRewardEngine.claimReleaseGift(
            appVersion: self.currentAppVersion,
            in: &state)
        if self.companionState.stage != .egg {
            self.companionRewardEngine.reconcileLevelMilestones(
                generationID: self.companionState.generationID,
                level: self.companionState.level,
                in: &state)
        }
        guard state != self.companionRewardState else { return }
        let shardIncrease = max(
            state.starShards - self.companionRewardState.starShards,
            0)
        self.companionRewardState = state
        self.companionRewardNoticeAmount = shardIncrease > 0
            ? shardIncrease
            : nil
        self.saveCompanionRewardState()
    }

    private func suppressImportedCompanionRewardBackfill() {
        let importedIDs = Set(
            self.companionState.legacyMigratedGenerationIDs)
        guard !importedIDs.isEmpty else { return }
        var reward = self.companionRewardState
        if self.companionState.stage != .egg,
           importedIDs.contains(self.companionState.generationID)
        {
            self.companionRewardEngine.suppressImportedLevelBackfill(
                generationID: self.companionState.generationID,
                level: self.companionState.level,
                in: &reward)
        }
        for companion in self.companionState.collection.archivedGenerations
            where importedIDs.contains(companion.generationID)
        {
            self.companionRewardEngine.suppressImportedLevelBackfill(
                generationID: companion.generationID,
                level: CompanionLevelCurve.standard.level(
                    forXP: companion.growthXP),
                in: &reward)
        }
        self.companionRewardState = reward
    }

    private func saveCompanionRewardState() {
        let state = self.companionRewardState
        self.companionRewardSaveRevision &+= 1
        let revision = self.companionRewardSaveRevision
        Task {
            try? await self.companionRewardStateStore.save(state, revision: revision)
        }
    }

    private func reconcileLegacyCompanionPalettes() {
        var state = self.companionRewardState
        let legacyVariants = self.companionState.collection.discoveredVariantIDs
        if legacyVariants.contains(.legacyAzure) {
            state.unlockedCosmeticIDs.insert(.azurePalette)
        }
        if legacyVariants.contains(.legacyViolet) {
            state.unlockedCosmeticIDs.insert(.violetPalette)
        }
        guard state != self.companionRewardState else { return }
        state.updatedAt = .now
        self.companionRewardState = state
        self.saveCompanionRewardState()
    }

    private func refreshPricingCatalogIfNeeded(force: Bool = false) async {
        if !force,
           let lastCheck = UserDefaults.standard.object(
               forKey: Self.pricingCatalogLastCheckKey) as? Date,
           Calendar.current.isDate(lastCheck, inSameDayAs: .now)
        {
            return
        }
        UserDefaults.standard.set(Date.now, forKey: Self.pricingCatalogLastCheckKey)
        do {
            let result = try await self.pricingCatalogClient.refresh()
            self.applyPricingCatalogResult(result)
            self.pricingUpdateMessage = nil
        } catch {
            self.pricingUpdateMessage = AppLocalization.string("settings.cost.catalogFailed")
        }
    }

    private func checkForAppUpdate(force: Bool = false) async {
        guard !self.isCheckingForAppUpdate else { return }
        self.isCheckingForAppUpdate = true
        defer { self.isCheckingForAppUpdate = false }
        do {
            self.appUpdateResult = try await self.appUpdateClient.check(
                currentVersion: self.currentAppVersion,
                force: force)
            self.appUpdateMessage = nil
        } catch {
            self.appUpdateMessage = AppLocalization.string("settings.updates.failed")
        }
    }

    private func performAppUpdateInstallation() async {
        defer {
            self.isInstallingAppUpdate = false
            self.appUpdateInstallationOperation = nil
            self.appUpdateInstallationTask = nil
        }
        do {
            guard let releaseVersion = self.appUpdateResult?.latestRelease.version else {
                throw HomebrewUpdateError.invalidResponse
            }
            self.appUpdateInstallationOperation = .readInstallation
            guard let brew = HomebrewUpdateService.locateBrew() else {
                throw HomebrewUpdateError.homebrewNotFound
            }
            _ = try await self.homebrewUpdateService.readFormulaInfo(brew: brew)

            self.appUpdateInstallationOperation = .refreshDefinitions
            try await self.homebrewUpdateService.refreshDefinitions(brew: brew)

            self.appUpdateInstallationOperation = .readInstallation
            let formula = try await self.homebrewUpdateService.readFormulaInfo(brew: brew)
            guard formula.isAvailable(for: releaseVersion) else {
                self.appUpdateInstallationMessage = AppLocalization.string(
                    "settings.updates.formulaPending")
                return
            }

            if formula.isUpdateAvailable {
                self.appUpdateInstallationOperation = .upgradeFormula
                try await self.homebrewUpdateService.upgradeFormula(brew: brew)
            }

            self.appUpdateInstallationOperation = .relinkApplication
            try await self.homebrewUpdateService.relinkApplication(brew: brew)
            let applicationPath = try await self.homebrewUpdateService.applicationPath(brew: brew)

            self.appUpdateInstallationOperation = .restartApplication
            try await self.homebrewUpdateService.restartApplication(
                applicationPath: applicationPath,
                processIdentifier: ProcessInfo.processInfo.processIdentifier)
            NSApplication.shared.terminate(nil)
        } catch is CancellationError {
            self.appUpdateInstallationMessage = AppLocalization.string(
                "settings.updates.cancelled")
        } catch HomebrewUpdateError.formulaNotInstalled {
            self.appUpdateRequiresFormulaMigration = true
            self.appUpdateInstallationMessage = AppLocalization.string(
                "settings.updates.migrationRequired")
        } catch HomebrewUpdateError.homebrewNotFound {
            self.appUpdateInstallationMessage = AppLocalization.string(
                "settings.updates.homebrewMissing")
        } catch let HomebrewUpdateError.commandFailed(_, message) {
            self.appUpdateInstallationMessage = AppLocalization.format(
                "settings.updates.installFailed",
                message)
        } catch {
            self.appUpdateInstallationMessage = AppLocalization.string(
                "settings.updates.installUnknownFailed")
        }
    }

    private func applyPricingCatalogResult(_ result: PricingCatalogUpdateResult) {
        self.pricingCatalogMetadata = result.metadata
        self.pricingCatalogSource = result.source
    }
}
