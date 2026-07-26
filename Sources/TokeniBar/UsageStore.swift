import TokeniCore
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

    private let providers: [any UsageProviding]
    private var refreshLoop: Task<Void, Never>?
    private var activityLoop: Task<Void, Never>?
    private let notificationController: UsageNotificationController
    private let launchAtLoginController: LaunchAtLoginController
    private let historyStore: UsageHistoryStore
    private let exchangeRateClient: DailyExchangeRateClient
    private let pricingCatalogClient: PricingCatalogUpdateClient
    private let appUpdateClient: GitHubReleaseUpdateClient
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

    init(providers: [any UsageProviding] = ProviderRegistry.defaultProviders()) {
        let knownIDs = Set(providers.map { $0.descriptor.id })
        self.providers = providers
        let notificationController = UsageNotificationController()
        let launchAtLoginController = LaunchAtLoginController()
        let historyStore = UsageHistoryStore()
        let exchangeRateClient = DailyExchangeRateClient()
        let pricingCatalogClient = PricingCatalogUpdateClient()
        let appUpdateClient = GitHubReleaseUpdateClient()
        self.notificationController = notificationController
        self.launchAtLoginController = launchAtLoginController
        self.historyStore = historyStore
        self.exchangeRateClient = exchangeRateClient
        self.pricingCatalogClient = pricingCatalogClient
        self.appUpdateClient = appUpdateClient
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
        } else {
            self.activityLoop?.cancel()
            self.activityLoop = nil
            self.providerActivities = Dictionary(uniqueKeysWithValues: self.providers.map {
                ($0.descriptor.id, ProviderActivitySnapshot(
                    providerID: $0.descriptor.id,
                    state: .unknown))
            })
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
        guard self.activityAnimationsEnabled, self.activityLoop == nil else { return }
        self.activityLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshActivity()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func refreshActivity() async {
        guard self.activityAnimationsEnabled else { return }
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
        if self.hasActiveSession {
            self.activityAnimationPulse &+= 1
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

    private func applyPricingCatalogResult(_ result: PricingCatalogUpdateResult) {
        self.pricingCatalogMetadata = result.metadata
        self.pricingCatalogSource = result.source
    }
}
