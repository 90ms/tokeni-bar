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
    @Published private(set) var isCompanionEvolving: Bool
    @Published private(set) var companionRewardState: CompanionRewardState
    @Published private(set) var companionBenefitState: CompanionBenefitState
    @Published private(set) var companionBenefitError: CompanionBenefitError?
    @Published private(set) var companionRewardNoticeAmount: Int?
    @Published private(set) var companionAttendanceError: CompanionRewardError?

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
        self.companionAnimationIntensity = UserDefaults.standard.string(
            forKey: Self.companionAnimationIntensityKey)
            .flatMap(CompanionAnimationIntensity.init(rawValue:))
            ?? (legacyCompanionAnimationsEnabled ? .full : .off)
        self.companionAnimationsEnabled =
            self.companionAnimationIntensity.isEnabled
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
        self.isCompanionEvolving = false
        self.companionRewardState = CompanionRewardState()
        self.companionBenefitState = CompanionBenefitState()
        self.companionBenefitError = nil
        self.companionRewardNoticeAmount = nil
        self.companionAttendanceError = nil
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
            self.companionState = (try? await self.companionStateStore.load())
                ?? CompanionGameState()
            self.companionGameEngine.rollOverEnergyIfNeeded(
                in: &self.companionState)
            self.companionRewardState =
                (try? await self.companionRewardStateStore.load())
                    ?? CompanionRewardState()
            self.companionBenefitState =
                (try? await self.companionBenefitStateStore.load())
                    ?? CompanionBenefitState()
            self.companionBenefitEngine.reconcileSlots(
                unlockedFormCount: self.companionState.collection.unlockedFormCount,
                in: &self.companionBenefitState)
            self.reconcileCompanionRewards()
            self.tokenGrowthLedgerState = (try? await self.tokenGrowthLedgerStore.load())
                ?? TokenGrowthLedgerState()
            self.companionStateLoaded = true
            self.saveCompanionState()
            self.saveCompanionBenefitState()
            await self.applyPendingCompanionGrowthAwards()
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
              self.companionState.stage == .egg
        else { return }
        var state = self.companionState
        guard let events = try? self.companionGameEngine.hatch(
            speciesUnitValue: Double.random(in: 0..<1),
            variantUnitValue: Double.random(in: 0..<1),
            personalityUnitValue: Double.random(in: 0..<1),
            in: &state)
        else { return }
        self.companionState = state
        for event in events {
            if case let .hatched(speciesID, rarity, isNewSpecies, _) = event {
                self.companionReveal = CompanionHatchReveal(
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

    func evolveCompanion() {
        guard self.companionEnabled,
              self.companionStateLoaded,
              !self.isCompanionEvolving,
              self.companionState.stage == .hatchling
                || self.companionState.stage == .junior
        else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.evolve(
            unitValue: Double.random(in: 0..<1),
            in: &state)) != nil
        else { return }
        self.companionState = state
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

    func completeCompanionGeneration() {
        guard self.companionEnabled,
              self.companionStateLoaded,
              self.companionState.stage == .adult
        else { return }
        var state = self.companionState
        guard let events = try? self.companionGameEngine.completeGeneration(
            speciesUnitValue: Double.random(in: 0..<1),
            variantUnitValue: Double.random(in: 0..<1),
            personalityUnitValue: Double.random(in: 0..<1),
            in: &state)
        else {
            return
        }
        self.companionState = state
        for event in events {
            if case let .hatched(speciesID, rarity, isNewSpecies, _) = event {
                self.companionReveal = CompanionHatchReveal(
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

    func abandonCompanionForNewEgg() {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.abandonForNewEgg(
            in: &state)) != nil else {
            return
        }
        self.companionState = state
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
        self.isShowingArchivedCompanion ? .adult : self.companionStage
    }

    var displayedCompanionRarity: CompanionRarity? {
        self.showcasedCompanion?.finalRarity ?? self.companionState.rarity
    }

    var displayedCompanionVariantID: CompanionVariantID? {
        if let showcased = self.showcasedCompanion {
            return showcased.variantID
                ?? CompanionVariantRegistry.migrated(
                    from: showcased.finalRarity)
        }
        return self.companionState.resolvedVariantID
    }

    var displayedCompanionNickname: String? {
        self.showcasedCompanion?.nickname ?? self.companionState.nickname
    }

    var displayedCompanionPersonalityID: CompanionPersonalityID? {
        self.showcasedCompanion?.personalityID
            ?? self.companionState.personalityID
    }

    var displayedCompanionBondLevel: Int {
        CompanionBond.level(for: self.displayedCompanionBondEnergy)
    }

    var displayedCompanionBondEnergy: Int {
        self.showcasedCompanion?.bondEnergy ?? self.companionState.bondEnergy
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

    var companionCostDiscountBasisPoints: Int {
        self.companionBenefitEngine.actionCostDiscountBasisPoints(
            passives: self.companionActivePassives)
    }

    var companionLuckyCheerBasisPoints: Int {
        self.companionBenefitEngine.luckyCheerBasisPoints(
            passives: self.companionActivePassives)
    }

    var companionRewardAbsorptionBasisPoints: Int {
        self.companionBenefitEngine.rewardAbsorptionBasisPoints(
            passives: self.companionActivePassives)
    }

    var companionBehavior: CompanionBehavior {
        CompanionBehaviorResolver.resolve(
            state: self.companionState,
            isWorking: self.hasActiveSession,
            lowestRemainingQuotaPercent: self.menuBarRemainingPercent)
    }

    var companionStageProgress: Double {
        guard let cost = self.companionActionCost, cost > 0 else { return 1 }
        return min(
            Double(self.companionState.growthEnergy) / Double(cost),
            1)
    }

    var companionNextStageEnergy: Int? {
        self.companionActionCost
    }

    var companionActionCost: Int? {
        self.companionGameEngine.actionCost(for: self.companionStage)
    }

    var companionNewEggCost: Int {
        self.companionGameEngine.discountedCost(
            self.companionGameEngine.rules.newEggCost,
            basisPoints: 0)
    }

    var companionJourneyCompletionCost: Int {
        self.companionGameEngine.discountedCost(
            self.companionGameEngine.rules.journeyCompletionCost,
            basisPoints: 0)
    }

    var companionPrismaticPityHatches: Int {
        self.companionGameEngine.rules.prismaticPityHatches
    }

    var canPerformCompanionAction: Bool {
        !self.isCompanionEvolving
            && self.companionGameEngine.canPerformAction(
                for: self.companionState)
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
        self.companionEnabled && self.companionOverlayEnabled
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
                try? await Task.sleep(for: .seconds(3))
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
        self.saveCompanionState()
    }

    private func processCompanionGrowth(at now: Date) async {
        guard self.companionEnabled, self.companionStateLoaded else { return }
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
            let events: [CompanionGameEvent]
            do {
                events = self.companionGameEngine.apply(
                    award: award,
                    to: &companion)
                self.companionStateSaveRevision &+= 1
                try await self.companionStateStore.save(
                    companion,
                    revision: self.companionStateSaveRevision)
            } catch {
                return
            }
            self.companionState = companion
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
        var state = self.companionRewardState
        var grants = self.companionRewardEngine.reconcile(
            collection: self.companionState.collection,
            in: &state)
        if let grant = self.companionRewardEngine.rewardVerifiedGrowth(
            energy: self.companionState.growthEarnedToday,
            in: &state)
        {
            grants.append(grant)
        }
        if let grant = self.companionRewardEngine.claimReleaseGift(
            appVersion: self.currentAppVersion,
            in: &state)
        {
            grants.append(grant)
        }
        guard !grants.isEmpty else { return }
        self.companionRewardState = state
        self.companionRewardNoticeAmount = grants.reduce(0) { $0 + $1.amount }
        self.saveCompanionRewardState()
    }

    private func saveCompanionRewardState() {
        let state = self.companionRewardState
        self.companionRewardSaveRevision &+= 1
        let revision = self.companionRewardSaveRevision
        Task {
            try? await self.companionRewardStateStore.save(state, revision: revision)
        }
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
            self.appUpdateInstallationOperation = .readInstallation
            guard let brew = HomebrewUpdateService.locateBrew() else {
                throw HomebrewUpdateError.homebrewNotFound
            }
            _ = try await self.homebrewUpdateService.readFormulaInfo(brew: brew)

            self.appUpdateInstallationOperation = .refreshDefinitions
            try await self.homebrewUpdateService.refreshDefinitions(brew: brew)

            self.appUpdateInstallationOperation = .readInstallation
            let formula = try await self.homebrewUpdateService.readFormulaInfo(brew: brew)
            guard formula.isUpdateAvailable else {
                self.appUpdateInstallationMessage = AppLocalization.string(
                    "settings.updates.formulaPending")
                return
            }

            self.appUpdateInstallationOperation = .upgradeFormula
            try await self.homebrewUpdateService.upgradeFormula(brew: brew)

            self.appUpdateInstallationOperation = .relinkApplication
            try await self.homebrewUpdateService.relinkApplication(brew: brew)

            self.appUpdateInstallationOperation = .restartApplication
            try await self.homebrewUpdateService.restartApplication(
                homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path)
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
