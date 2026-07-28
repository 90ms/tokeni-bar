import TokeniCore
import AppKit
import Foundation

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
    @Published private(set) var companionState: CompanionGameState
    @Published private(set) var companionReveal: CompanionHatchReveal?
    @Published private(set) var companionRewardState: CompanionRewardState
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
    private let tokenGrowthLedgerStore: TokenGrowthLedgerStore
    private let companionGameEngine = CompanionGameEngine()
    private let companionRewardEngine = CompanionRewardEngine()
    private let tokenGrowthLedgerEngine = TokenGrowthLedgerEngine()
    private var tokenGrowthLedgerState: TokenGrowthLedgerState
    private var companionStateLoaded = false
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
    private static let notificationProviderIDsKey = "usageNotificationProviderIDs"
    private static let costDisplayCurrencyKey = "costDisplayCurrency"
    private static let monthlyBudgetEnabledKey = "monthlyBudgetEnabled"
    private static let monthlyBudgetAmountKey = "monthlyBudgetAmount"
    private static let monthlyBudgetCurrencyKey = "monthlyBudgetCurrency"
    private static let pricingCatalogLastCheckKey = "pricingCatalogLastCheck"
    private static let companionEnabledKey = "companionEnabled"
    private static let companionAnimationsEnabledKey = "companionAnimationsEnabled"

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
        self.tokenGrowthLedgerStore = tokenGrowthLedgerStore
        self.tokenGrowthLedgerState = TokenGrowthLedgerState()
        self.notificationsEnabled = notificationController.isEnabled
        self.notificationSettingsMessage = nil
        self.authorizingProviderIDs = []
        self.providerAuthorizationMessages = [:]
        self.warningThreshold = UserDefaults.standard.object(forKey: Self.warningThresholdKey) as? Int ?? 30
        self.criticalThreshold = UserDefaults.standard.object(forKey: Self.criticalThresholdKey) as? Int ?? 10
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
        self.companionAnimationsEnabled = UserDefaults.standard.object(
            forKey: Self.companionAnimationsEnabledKey) as? Bool ?? true
        self.companionState = CompanionGameState()
        self.companionReveal = nil
        self.companionRewardState = CompanionRewardState()
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
            self.reconcileCompanionRewards()
            self.tokenGrowthLedgerState = (try? await self.tokenGrowthLedgerStore.load())
                ?? TokenGrowthLedgerState()
            self.companionStateLoaded = true
            self.saveCompanionState()
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
        self.notificationController.process(
            self.snapshots,
            warningThreshold: self.warningThreshold,
            criticalThreshold: self.criticalThreshold,
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

    func setCompanionAnimationsEnabled(_ enabled: Bool) {
        self.companionAnimationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.companionAnimationsEnabledKey)
    }

    func patCompanion() {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        self.companionGameEngine.pat(in: &state)
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
            rarityUnitValue: Double.random(in: 0..<1),
            in: &state)
        else { return }
        self.companionState = state
        for event in events {
            if case let .hatched(speciesID, rarity, isNewSpecies, _) = event {
                self.companionReveal = CompanionHatchReveal(
                    speciesID: speciesID,
                    rarity: rarity,
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
              self.companionState.stage == .hatchling
                || self.companionState.stage == .junior
        else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.evolve(
            unitValue: Double.random(in: 0..<1),
            in: &state)) != nil
        else { return }
        self.companionState = state
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
            rarityUnitValue: Double.random(in: 0..<1),
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
                    isNewSpecies: isNewSpecies)
            }
        }
        self.reconcileCompanionRewards()
        self.saveCompanionState()
    }

    func abandonCompanionForNewEgg() {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionState
        guard (try? self.companionGameEngine.abandonForNewEgg(in: &state)) != nil else {
            return
        }
        self.companionState = state
        self.saveCompanionState()
    }

    func claimCompanionAttendance() {
        guard self.companionEnabled, self.companionStateLoaded else { return }
        var state = self.companionRewardState
        do {
            let grants = try self.companionRewardEngine.checkIn(in: &state)
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

    var companionDisplayRarity: CompanionRarity {
        self.companionState.rarity ?? .normal
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
        self.companionGameEngine.rules.newEggCost
    }

    var companionJourneyCompletionCost: Int {
        self.companionGameEngine.rules.journeyCompletionCost
    }

    var canPerformCompanionAction: Bool {
        self.companionGameEngine.canPerformAction(for: self.companionState)
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
            budgetText: budget)
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
            try await self.tokenGrowthLedgerStore.save(ledger)
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
            do {
                _ = self.companionGameEngine.apply(
                    award: award,
                    to: &companion)
                try await self.companionStateStore.save(companion)
            } catch {
                return
            }
            self.companionState = companion

            var ledger = self.tokenGrowthLedgerState
            self.tokenGrowthLedgerEngine.markApplied(award.id, in: &ledger)
            do {
                try await self.tokenGrowthLedgerStore.save(ledger)
                self.tokenGrowthLedgerState = ledger
            } catch {
                return
            }
        }
    }

    private func saveCompanionState() {
        let state = self.companionState
        Task {
            try? await self.companionStateStore.save(state)
        }
    }

    private func reconcileCompanionRewards() {
        var state = self.companionRewardState
        let grants = self.companionRewardEngine.reconcile(
            collection: self.companionState.collection,
            in: &state)
        guard !grants.isEmpty else { return }
        self.companionRewardState = state
        self.companionRewardNoticeAmount = grants.reduce(0) { $0 + $1.amount }
        self.saveCompanionRewardState()
    }

    private func saveCompanionRewardState() {
        let state = self.companionRewardState
        Task {
            try? await self.companionRewardStateStore.save(state)
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
