import AppKit
import Combine
import TokeniCore
import SwiftUI

private enum SettingsTab: Hashable {
    case general
    case notifications
    case companion
    case usage
    case privacy
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab = SettingsTab.general
    @State private var showsNotificationDiagnostics = false

    var body: some View {
        TabView(selection: self.$selectedTab) {
            self.generalTab
                .tag(SettingsTab.general)
                .tabItem {
                    Label(
                        AppLocalization.string("settings.tab.general"),
                        systemImage: "gearshape")
                }

            self.notificationsTab
                .tag(SettingsTab.notifications)
                .tabItem {
                    Label(
                        AppLocalization.string("settings.tab.notifications"),
                        systemImage: "bell")
                }

            self.companionTab
                .tag(SettingsTab.companion)
                .tabItem {
                    Label(
                        AppLocalization.string("settings.tab.companion"),
                        systemImage: "face.smiling")
                }

            self.usageTab
                .tag(SettingsTab.usage)
                .tabItem {
                    Label(
                        AppLocalization.string("settings.tab.usage"),
                        systemImage: "chart.xyaxis.line")
                }

            self.privacyTab
                .tag(SettingsTab.privacy)
                .tabItem {
                    Label(
                        AppLocalization.string("settings.tab.privacy"),
                        systemImage: "hand.raised")
                }
        }
        .frame(width: 560, height: 520)
        .padding()
        .onReceive(NotificationCenter.default.publisher(
            for: .openNotificationSettings))
        { _ in
            self.selectedTab = .notifications
        }
    }

    private var companionTab: some View {
        Form {
            Section(AppLocalization.string("settings.companion.title")) {
                Toggle(isOn: Binding(
                    get: { self.store.companionEnabled },
                    set: { self.store.setCompanionEnabled($0) }))
                {
                    Text(AppLocalization.string("settings.companion.enabled"))
                }

                if self.store.companionEnabled {
                    Picker(
                        AppLocalization.string(
                            "settings.companion.animationIntensity"),
                        selection: Binding(
                            get: {
                                self.store.companionAnimationIntensity
                            },
                            set: {
                                self.store.setCompanionAnimationIntensity($0)
                            }))
                    {
                        ForEach(CompanionAnimationIntensity.allCases) {
                            intensity in
                            Text(intensity.localizedName)
                                .tag(intensity)
                        }
                    }
                    Text(AppLocalization.string("settings.companion.motion"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: Binding(
                        get: { self.store.companionOverlayEnabled },
                        set: { self.store.setCompanionOverlayEnabled($0) }))
                    {
                        Text(AppLocalization.string("settings.companion.overlay"))
                    }
                    Text(AppLocalization.string("settings.companion.overlay.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if self.store.companionOverlayEnabled {
                        Picker(
                            AppLocalization.string("settings.companion.overlay.size"),
                            selection: Binding(
                                get: { self.store.companionOverlaySize },
                                set: { self.store.setCompanionOverlaySize($0) }))
                        {
                            ForEach(CompanionOverlaySize.allCases) { size in
                                Text(size.localizedName).tag(size)
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { self.store.companionOverlayPositionLocked },
                            set: { self.store.setCompanionOverlayPositionLocked($0) }))
                        {
                            Text(AppLocalization.string(
                                "settings.companion.overlay.positionLocked"))
                        }

                        Toggle(isOn: Binding(
                            get: {
                                self.store.companionOverlayClickThroughEnabled
                            },
                            set: {
                                self.store.setCompanionOverlayClickThroughEnabled($0)
                            }))
                        {
                            Text(AppLocalization.string(
                                "settings.companion.overlay.clickThrough"))
                        }
                        Text(AppLocalization.string(
                            "settings.companion.overlay.clickThrough.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(AppLocalization.string(
                            "settings.companion.overlay.resetPosition"))
                        {
                            self.store.resetCompanionOverlayPosition()
                        }
                    }

                    Button(AppLocalization.string("companion.collection.open")) {
                        self.openWindow(id: "companion-collection")
                        Task { @MainActor in
                            await Task.yield()
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section(AppLocalization.string("settings.language")) {
                Picker(
                    AppLocalization.string("settings.language"),
                    selection: Binding(
                        get: { self.store.appLanguage },
                        set: { self.store.setAppLanguage($0) }))
                {
                    Text(AppLocalization.string("settings.language.system"))
                        .tag(AppLanguage.system)
                    Text(AppLocalization.string("settings.language.korean"))
                        .tag(AppLanguage.korean)
                    Text(AppLocalization.string("settings.language.english"))
                        .tag(AppLanguage.english)
                }
            }

            Section(AppLocalization.string("settings.providers")) {
                ForEach(self.store.descriptors) { descriptor in
                    self.providerSettingsRow(descriptor)
                }
                if !self.store.authorizationDescriptors.isEmpty {
                    Text(AppLocalization.string("settings.connections.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(AppLocalization.string("settings.menuBar")) {
                Picker(
                    AppLocalization.string("settings.menuBar.display"),
                    selection: Binding(
                        get: { self.store.menuBarDisplayMode },
                        set: { self.store.setMenuBarDisplayMode($0) }))
                {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }

                if self.store.menuBarDisplayMode == .selectedProvider {
                    Picker(
                        AppLocalization.string("settings.menuBar.provider"),
                        selection: Binding(
                            get: { self.store.selectedMenuBarProviderID },
                            set: { self.store.setSelectedMenuBarProviderID($0) }))
                    {
                        ForEach(self.store.descriptors) { descriptor in
                            Label {
                                Text(descriptor.displayName)
                            } icon: {
                                ProviderIcon(descriptor: descriptor)
                            }
                            .tag(descriptor.id)
                        }
                    }

                    if self.store.selectedMenuBarProviderID == .claude {
                        Picker(
                            AppLocalization.string("settings.menuBar.claudeQuota"),
                            selection: Binding(
                                get: { self.store.claudeMenuBarQuota },
                                set: { self.store.setClaudeMenuBarQuota($0) }))
                        {
                            ForEach(ClaudeMenuBarQuota.allCases) { quota in
                                Text(quota.localizedName).tag(quota)
                            }
                        }
                    }
                }

                Toggle(isOn: Binding(
                    get: { self.store.compactModeEnabled },
                    set: { self.store.setCompactModeEnabled($0) }))
                {
                    Text(AppLocalization.string("settings.menuBar.compact"))
                }
                Text(AppLocalization.string("settings.menuBar.compact.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(isOn: Binding(
                    get: { self.store.activityAnimationsEnabled },
                    set: { self.store.setActivityAnimationsEnabled($0) }))
                {
                    Text(AppLocalization.string("settings.activity.enabled"))
                }
                if self.store.activityAnimationsEnabled {
                    Picker(
                        AppLocalization.string("settings.activity.window"),
                        selection: Binding(
                            get: { self.store.activityWindowSeconds },
                            set: { self.store.setActivityWindowSeconds($0) }))
                    {
                        ForEach([10, 15, 30], id: \.self) { seconds in
                            Text(AppLocalization.format(
                                "settings.activity.seconds",
                                seconds))
                                .tag(seconds)
                        }
                    }
                    Text(AppLocalization.string("settings.activity.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: Binding(
                    get: { self.store.launchAtLoginEnabled },
                    set: { self.store.setLaunchAtLoginEnabled($0) }))
                {
                    Text(AppLocalization.string("settings.launchAtLogin"))
                }
                if let message = self.store.launchAtLoginMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(AppLocalization.string("settings.updates.title")) {
                HStack {
                    Text(AppLocalization.format(
                        "settings.updates.current",
                        self.store.currentAppVersion))
                    Spacer()
                    Button(AppLocalization.string("settings.updates.check")) {
                        self.store.refreshAppUpdate()
                    }
                    .disabled(self.store.isCheckingForAppUpdate)
                }

                if self.store.isCheckingForAppUpdate {
                    ProgressView()
                        .controlSize(.small)
                } else if let result = self.store.appUpdateResult {
                    if result.isUpdateAvailable {
                        HStack {
                            Link(
                                AppLocalization.format(
                                    "settings.updates.available",
                                    result.latestRelease.version.description),
                                destination: result.latestRelease.pageURL)
                            Spacer()
                            Button(AppLocalization.string("settings.updates.install")) {
                                self.store.installAppUpdate()
                            }
                            .disabled(self.store.isInstallingAppUpdate)
                        }
                    } else {
                        Text(AppLocalization.string("settings.updates.latest"))
                            .foregroundStyle(.secondary)
                    }
                    if result.isStale {
                        TokeniStatusBanner(
                            text: AppLocalization.string(
                                "settings.updates.stale"),
                            kind: .warning)
                    }
                } else if let message = self.store.appUpdateMessage {
                    TokeniStatusBanner(text: message, kind: .error)
                }

                if self.store.isInstallingAppUpdate,
                   let operation = self.store.appUpdateInstallationOperation
                {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(self.updateOperationText(operation))
                            .font(.caption)
                        Spacer()
                        Button(AppLocalization.string("settings.updates.cancel")) {
                            self.store.cancelAppUpdateInstallation()
                        }
                    }
                } else if let message = self.store.appUpdateInstallationMessage {
                    TokeniStatusBanner(text: message, kind: .warning)
                }

                if self.store.appUpdateRequiresFormulaMigration {
                    Link(
                        AppLocalization.string("settings.updates.migrationGuide"),
                        destination: URL(
                            string: AppLocalization.string(
                                "settings.updates.migrationGuideURL"))
                            ?? URL(string: "https://github.com/90ms/tokeni-bar")!)
                }

                Text(AppLocalization.string("settings.updates.manual"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func providerSettingsRow(
        _ descriptor: ProviderDescriptor) -> some View
    {
        let requiresAuthorization = self.store.authorizationDescriptors
            .contains { $0.id == descriptor.id }
        let state = self.store.connectionState(for: descriptor.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: Binding(
                    get: { self.store.isEnabled(descriptor.id) },
                    set: {
                        self.store.setEnabled($0, for: descriptor.id)
                    }))
                {
                    Label {
                        Text(descriptor.displayName)
                    } icon: {
                        ProviderIcon(descriptor: descriptor)
                    }
                }

                if requiresAuthorization {
                    if self.store.authorizingProviderIDs
                        .contains(descriptor.id)
                    {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(AppLocalization.string(
                            "settings.connections.connect"))
                        {
                            self.store.requestUsageAuthorization(
                                for: descriptor.id)
                        }
                        .disabled(!self.store.isEnabled(descriptor.id))
                    }
                }
            }

            if requiresAuthorization {
                if let message =
                    self.store.providerAuthorizationMessages[descriptor.id]
                {
                    TokeniStatusBanner(
                        text: message,
                        kind: state == .connected ? .success : .warning)
                } else {
                    Label(
                        AppLocalization.string(
                            "settings.connections.state.\(state.rawValue)"),
                        systemImage: self.connectionStateIcon(state))
                        .font(.caption)
                        .foregroundStyle(self.connectionStateColor(state))
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func connectionStateIcon(
        _ state: ProviderConnectionState) -> String
    {
        switch state {
        case .connected: "checkmark.circle.fill"
        case .localOnly: "doc.text.magnifyingglass"
        case .authorizationRequired: "key.fill"
        case .sessionExpired: "clock.badge.exclamationmark"
        case .stale: "exclamationmark.triangle.fill"
        }
    }

    private func connectionStateColor(
        _ state: ProviderConnectionState) -> Color
    {
        switch state {
        case .connected: .green
        case .localOnly: .secondary
        case .authorizationRequired, .sessionExpired, .stale: .orange
        }
    }

    private func updateOperationText(_ operation: HomebrewUpdateOperation) -> String {
        AppLocalization.string("settings.updates.operation.\(operation.rawValue)")
    }

    private var notificationsTab: some View {
        Form {
            Section(AppLocalization.string("settings.notifications")) {
                Toggle(isOn: Binding(
                    get: { self.store.notificationsEnabled },
                    set: { self.store.setNotificationsEnabled($0) }))
                {
                    Text(AppLocalization.string("settings.notifications.enabled"))
                }
                if let message = self.store.notificationSettingsMessage {
                    TokeniStatusBanner(text: message, kind: .warning)
                }
            }

            if self.store.notificationsEnabled {
                Section(AppLocalization.string(
                    "settings.notifications.usageAlerts"))
                {
                    Toggle(isOn: Binding(
                        get: { self.store.lowUsageNotificationsEnabled },
                        set: { self.store.setLowUsageNotificationsEnabled($0) }))
                    {
                        Text(AppLocalization.string(
                            "settings.notifications.lowUsage"))
                    }

                    if self.store.lowUsageNotificationsEnabled {
                        Picker(
                            AppLocalization.string("settings.notifications.warning"),
                            selection: Binding(
                                get: { self.store.warningThreshold },
                                set: { self.store.setWarningThreshold($0) }))
                        {
                            ForEach([50, 40, 30, 20], id: \.self) { value in
                                Text(AppLocalization.format(
                                    "settings.notifications.percentLeft",
                                    value))
                                    .tag(value)
                            }
                        }
                        Picker(
                            AppLocalization.string("settings.notifications.critical"),
                            selection: Binding(
                                get: { self.store.criticalThreshold },
                                set: { self.store.setCriticalThreshold($0) }))
                        {
                            ForEach([15, 10, 5], id: \.self) { value in
                                Text(AppLocalization.format(
                                    "settings.notifications.percentLeft",
                                    value))
                                    .tag(value)
                            }
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { self.store.budgetNotificationsEnabled },
                        set: { self.store.setBudgetNotificationsEnabled($0) }))
                    {
                        Text(AppLocalization.string(
                            "settings.notifications.budget"))
                    }
                }

                Section(AppLocalization.string(
                    "settings.notifications.resetAlerts"))
                {
                    Toggle(isOn: Binding(
                        get: { self.store.resetNotificationsEnabled },
                        set: { self.store.setResetNotificationsEnabled($0) }))
                    {
                        Text(AppLocalization.string(
                            "settings.notifications.reset"))
                    }
                    if self.store.resetNotificationsEnabled {
                        Text(AppLocalization.string(
                            "settings.notifications.reset.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppLocalization.string(
                    "settings.notifications.systemAlerts"))
                {
                    Toggle(isOn: Binding(
                        get: { self.store.connectionIssueNotificationsEnabled },
                        set: {
                            self.store.setConnectionIssueNotificationsEnabled($0)
                        }))
                    {
                        Text(AppLocalization.string(
                            "settings.notifications.connection"))
                    }
                }

                Section(AppLocalization.string(
                    "settings.notifications.delivery"))
                {
                    Toggle(isOn: Binding(
                        get: { self.store.notificationQuietHoursEnabled },
                        set: {
                            self.store.setNotificationQuietHoursEnabled($0)
                        }))
                    {
                        Text(AppLocalization.string(
                            "settings.notifications.quietHours"))
                    }
                    if self.store.notificationQuietHoursEnabled {
                        HStack {
                            Picker(
                                AppLocalization.string(
                                    "settings.notifications.quietStart"),
                                selection: Binding(
                                    get: {
                                        self.store.notificationQuietHoursStart
                                    },
                                    set: {
                                        self.store.setNotificationQuietHours(
                                            start: $0,
                                            end: self.store
                                                .notificationQuietHoursEnd)
                                    }))
                            {
                                ForEach(0..<24, id: \.self) {
                                    Text(String(format: "%02d:00", $0))
                                        .tag($0)
                                }
                            }
                            Picker(
                                AppLocalization.string(
                                    "settings.notifications.quietEnd"),
                                selection: Binding(
                                    get: {
                                        self.store.notificationQuietHoursEnd
                                    },
                                    set: {
                                        self.store.setNotificationQuietHours(
                                            start: self.store
                                                .notificationQuietHoursStart,
                                            end: $0)
                                    }))
                            {
                                ForEach(0..<24, id: \.self) {
                                    Text(String(format: "%02d:00", $0))
                                        .tag($0)
                                }
                            }
                        }
                    }

                    Divider()

                    ForEach(self.store.descriptors) { descriptor in
                        Toggle(isOn: Binding(
                            get: {
                                self.store.isNotificationEnabled(
                                    for: descriptor.id)
                            },
                            set: {
                                self.store.setNotificationEnabled(
                                    $0,
                                    for: descriptor.id)
                            }))
                        {
                            Label {
                                Text(AppLocalization.format(
                                    "settings.notifications.provider",
                                    descriptor.displayName))
                            } icon: {
                                ProviderIcon(descriptor: descriptor)
                            }
                        }
                    }
                }

                Section(AppLocalization.string(
                    "settings.notifications.testAndDiagnostics"))
                {
                    Button(AppLocalization.string("settings.notifications.test")) {
                        self.store.sendTestNotification()
                    }

                    DisclosureGroup(
                        AppLocalization.string(
                            "settings.notifications.diagnostics"),
                        isExpanded: self.$showsNotificationDiagnostics)
                    {
                        if self.store.notificationDiagnostics.isEmpty {
                            Text(AppLocalization.string(
                                "settings.notifications.diagnostics.empty"))
                                .foregroundStyle(.secondary)
                                .padding(.top, 5)
                        } else {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(
                                    Array(self.store.notificationDiagnostics
                                        .enumerated()),
                                    id: \.offset)
                                { _, message in
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 5)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var usageTab: some View {
        Form {
            Section(AppLocalization.string("settings.cost.title")) {
                Picker(
                    AppLocalization.string("settings.cost.currency"),
                    selection: Binding(
                        get: { self.store.costDisplayCurrency },
                        set: { self.store.setCostDisplayCurrency($0) }))
                {
                    Text(AppLocalization.string("settings.cost.usd"))
                        .tag(CostDisplayCurrency.usd)
                    Text(AppLocalization.string("settings.cost.krw"))
                        .tag(CostDisplayCurrency.krw)
                }
                .pickerStyle(.segmented)

                if let quote = self.store.exchangeRateQuote {
                    Text(AppLocalization.format(
                        "settings.cost.rate",
                        quote.rate.formatted(.number.precision(.fractionLength(2))),
                        quote.rateDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(AppLocalization.string("settings.cost.rateUnavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(AppLocalization.string("settings.cost.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                HStack {
                    Text(AppLocalization.format(
                        "settings.cost.catalog",
                        self.store.pricingCatalogMetadata.catalogVersion,
                        self.store.pricingCatalogMetadata.effectiveDate,
                        AppLocalization.string(
                            "settings.cost.catalogSource.\(self.store.pricingCatalogSource.rawValue)")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(AppLocalization.string("settings.cost.catalogRefresh")) {
                        self.store.refreshPricingCatalog()
                    }
                }
                if let message = self.store.pricingUpdateMessage {
                    TokeniStatusBanner(text: message, kind: .error)
                }
            }

            Section(AppLocalization.string("settings.budget.title")) {
                Toggle(isOn: Binding(
                    get: { self.store.monthlyBudgetEnabled },
                    set: { self.store.setMonthlyBudgetEnabled($0) }))
                {
                    Text(AppLocalization.string("settings.budget.enabled"))
                }
                if self.store.monthlyBudgetEnabled {
                    HStack {
                        TextField(
                            AppLocalization.string("settings.budget.amount"),
                            value: Binding(
                                get: { self.store.monthlyBudgetAmount },
                                set: { self.store.setMonthlyBudgetAmount($0) }),
                            format: .number.precision(.fractionLength(0...2)))
                            .frame(width: 140)
                        Picker(
                            AppLocalization.string("settings.cost.currency"),
                            selection: Binding(
                                get: { self.store.monthlyBudgetCurrency },
                                set: { self.store.setMonthlyBudgetCurrency($0) }))
                        {
                            Text("USD").tag(CostDisplayCurrency.usd)
                            Text("KRW").tag(CostDisplayCurrency.krw)
                        }
                        .pickerStyle(.segmented)
                    }

                    if let budgetUSD = self.store.monthlyBudgetUSD,
                       let spent = self.store.monthlyBudgetCurrency.formatted(
                           amountUSD: self.store.monthlyEstimatedSpendUSD,
                           exchangeRate: self.store.exchangeRateQuote),
                       let budget = self.store.monthlyBudgetCurrency.formatted(
                           amountUSD: budgetUSD,
                           exchangeRate: self.store.exchangeRateQuote)
                    {
                        ProgressView(
                            value: min(self.store.monthlyEstimatedSpendUSD, budgetUSD),
                            total: budgetUSD)
                        Text(AppLocalization.format("settings.budget.spent", spent, budget))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(AppLocalization.string("settings.budget.noRate"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text(AppLocalization.string("settings.budget.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(AppLocalization.string("history.title")) {
                Button(AppLocalization.string("history.open")) {
                    self.openWindow(id: "usage-history")
                }
                Text(AppLocalization.string("history.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var privacyTab: some View {
        Form {
            Section(AppLocalization.string("settings.privacy")) {
                Text(AppLocalization.string("settings.privacy.description"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.string("diagnostics.title")) {
                Button(AppLocalization.string("diagnostics.open")) {
                    self.openWindow(id: "provider-diagnostics")
                }
                Text(AppLocalization.string("diagnostics.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
