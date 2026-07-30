@testable import TokeniCore
import Foundation
import LocalAuthentication
import Security
import Testing

struct ProviderParserTests {
    @Test
    func codexParsesQuotaAndTokenUsage() throws {
        let file = try #require(Bundle.module.url(
            forResource: "codex-token-count",
            withExtension: "jsonl",
            subdirectory: "Fixtures"))
        let parsed = try #require(CodexLogParser.latestUsage(in: file))

        #expect(parsed.tokenUsage.totalTokens == 1750)
        #expect(parsed.tokenUsage.modelID == "gpt-5.6-sol")
        #expect(parsed.tokenUsage.inputTokens == 1000)
        #expect(parsed.tokenUsage.cachedInputTokens == 500)
        #expect(parsed.tokenUsage.outputTokens == 200)
        #expect(parsed.tokenUsage.reasoningTokens == 50)
        #expect(parsed.sessionID == "codex-token-count")
        #expect(parsed.quotaWindows.count == 2)
        #expect(parsed.quotaWindows[0].usedPercent == 32)
        #expect(parsed.credits?.balance == "12.50")
    }

    @Test
    func codexAccountUsageMapsWeeklyAndModelLimits() throws {
        let file = try #require(Bundle.module.url(
            forResource: "codex-account-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let response = try JSONDecoder().decode(
            CodexAccountUsageResponse.self,
            from: Data(contentsOf: file))
        let windows = response.quotaWindows()

        #expect(response.planType == "prolite")
        #expect(windows.map(\.label) == ["Weekly", "GPT-5.3-Codex-Spark weekly"])
        #expect(windows.map(\.usedPercent) == [28, 3])
        #expect(windows.map(\.remainingPercent) == [72, 97])
        #expect(response.creditBalance?.balance == "0")
    }

    @Test
    func codexUsesLatestConfirmedDailyBucketWhenTodayIsPending() throws {
        let observedAt = try #require(
            ISO8601DateFormatter().date(from: "2026-07-28T12:00:00Z"))
        let usage = AccountTokenUsageSummary(
            todayTokens: nil,
            latestDailyTokens: 352_031,
            currentMonthTokens: 1_000_000,
            lifetimeTokens: 2_000_000,
            localDate: "2026-07-28",
            latestBucketDate: "2026-07-27")

        let observation = try #require(CodexUsageProvider().growthObservation(
            accountUsage: usage,
            accountObservedAt: observedAt,
            localUsage: nil))

        #expect(observation.scope == .daily)
        #expect(observation.scopeID == "2026-07-27")
        #expect(observation.totalTokens == 352_031)
        #expect(observation.observedAt == observedAt)
    }

    @Test
    func codexCredentialParserAcceptsSnakeAndCamelCaseWithoutExposingToken() throws {
        let snake = try CodexAccountCredentials.decode(Data(
            #"{"tokens":{"access_token":"fake-token","account_id":"account-1"}}"#.utf8))
        let camel = try CodexAccountCredentials.decode(Data(
            #"{"tokens":{"accessToken":"fake-token","accountId":"account-2"}}"#.utf8))

        #expect(snake.accountID == "account-1")
        #expect(camel.accountID == "account-2")
    }

    @Test
    func codexResetCreditsMapCountTitlesAndExpiration() throws {
        let file = try #require(Bundle.module.url(
            forResource: "codex-reset-credits",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let response = try JSONDecoder().decode(
            CodexResetCreditsResponse.self,
            from: Data(contentsOf: file))
        let summary = response.summary()

        #expect(summary.availableCount == 2)
        #expect(summary.totalEarnedCount == 3)
        #expect(summary.credits.map(\.title) == ["Full reset", "Weekly reset"])
        #expect(summary.credits.allSatisfy { $0.status == "available" })
        #expect(summary.credits.allSatisfy { $0.expiresAt != nil })
    }

    @Test
    func codexUsageCacheExpiresAtQuotaResetAndSupportsManualInvalidation() async {
        let cache = CodexAccountUsageCache()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let futureResponse = CodexAccountUsageResponse(
            planType: "prolite",
            rateLimit: .init(
                primaryWindow: .init(
                    usedPercent: 25,
                    resetAt: now.addingTimeInterval(30).timeIntervalSince1970,
                    limitWindowSeconds: 604_800),
                secondaryWindow: nil),
            credits: nil,
            additionalRateLimits: nil)

        await cache.store(futureResponse, accountID: "account-1", fetchedAt: now)
        #expect(await cache.value(accountID: "account-1", maxAge: 60, now: now) != nil)
        #expect(await cache.value(
            accountID: "account-1",
            maxAge: 60,
            now: now.addingTimeInterval(31)) == nil)

        await cache.store(futureResponse, accountID: "account-1", fetchedAt: now)
        await cache.invalidate()
        #expect(await cache.value(accountID: "account-1", maxAge: 60, now: now) == nil)
    }

    @Test
    func claudeDeduplicatesStreamingUsageRecords() throws {
        let file = try #require(Bundle.module.url(
            forResource: "claude-usage",
            withExtension: "jsonl",
            subdirectory: "Fixtures"))
        let aggregate = try #require(
            ClaudeLogParser.aggregate(files: [file], since: .distantPast))
        let usage = aggregate.tokenUsage

        #expect(usage.inputTokens == 100)
        #expect(usage.cacheCreationInputTokens == 20)
        #expect(usage.cachedInputTokens == 80)
        #expect(usage.outputTokens == 30)
        #expect(usage.totalTokens == 230)
        #expect(usage.modelID == "claude-sonnet-4-6")
        #expect(abs((aggregate.costEstimate?.amountUSD ?? 0) - 0.000849) < 0.000_000_1)
    }

    @Test
    func providerIDsAreOpenForExtension() {
        let custom = ProviderID(rawValue: "another-agent")
        #expect(custom.rawValue == "another-agent")
        #expect(custom != .codex)
    }

    @Test
    func defaultRegistryIncludesSupportedProviders() {
        let descriptors = ProviderRegistry.defaultProviders().map(\.descriptor)
        let ids = descriptors.map(\.id)
        #expect(ids == [.codex, .claude, .grok, .gemini, .openCode])
        #expect(descriptors.map(\.iconAssetName) == [
            "openai",
            "claude",
            "grok",
            "gemini",
            "opencode",
        ])
    }

    @Test
    func usageAlertsChooseOneThresholdAndIgnoreContextWindows() {
        let descriptor = ProviderDescriptor(
            id: .codex,
            displayName: "Codex",
            shortName: "Codex",
            systemImage: "chart.bar",
            capabilities: .init(supportsQuotaWindows: true))
        let snapshot = ProviderSnapshot(
            descriptor: descriptor,
            availability: .available,
            source: .officialAPI,
            quotaWindows: [
                QuotaWindow(id: "weekly", kind: .weekly, label: "Weekly", usedPercent: 76),
                QuotaWindow(id: "critical", kind: .weekly, label: "Model weekly", usedPercent: 93),
                QuotaWindow(id: "context", kind: .context, label: "Context", usedPercent: 95),
            ])

        let alerts = UsageAlertEvaluator.candidates(
            in: [snapshot],
            warningThreshold: 30,
            criticalThreshold: 10,
            enabledProviderIDs: [.codex])

        #expect(alerts.map(\.threshold) == [30, 10])
        #expect(alerts.map(\.windowID) == ["weekly", "critical"])
        #expect(Set(alerts.map(\.identifier)).count == 2)
        #expect(UsageSummary.minimumRemainingPercent(in: [snapshot]) == 5)
        #expect(UsageSummary.minimumRemainingPercent(in: [snapshot], for: .codex) == 5)
        #expect(UsageSummary.minimumRemainingPercent(in: [snapshot], for: .claude) == nil)
    }

    @Test
    func resetAlertsUseVerifiedUpcomingResetAndDeduplicateByCycle() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let descriptor = ProviderDescriptor(
            id: .claude,
            displayName: "Claude Code",
            shortName: "Claude",
            systemImage: "sparkles",
            capabilities: .init(supportsQuotaWindows: true))
        let snapshot = ProviderSnapshot(
            descriptor: descriptor,
            availability: .available,
            source: .officialAPI,
            quotaWindows: [
                QuotaWindow(
                    id: "session",
                    kind: .session,
                    label: "5-hour",
                    usedPercent: 75,
                    resetsAt: now.addingTimeInterval(59 * 60)),
                QuotaWindow(
                    id: "weekly",
                    kind: .weekly,
                    label: "Weekly",
                    usedPercent: 40,
                    resetsAt: now.addingTimeInterval(2 * 60 * 60)),
                QuotaWindow(
                    id: "context",
                    kind: .context,
                    label: "Context",
                    usedPercent: 90,
                    resetsAt: now.addingTimeInterval(30 * 60)),
            ])

        let alerts = UsageAlertEvaluator.resetCandidates(
            in: [snapshot],
            now: now,
            enabledProviderIDs: [.claude])

        #expect(alerts.count == 1)
        #expect(alerts[0].windowID == "session")
        #expect(alerts[0].remainingPercent == 25)
        #expect(alerts[0].timeRemaining == 59 * 60)
        #expect(alerts[0].identifier == "reset.claude.session.1800003540")
        #expect(UsageAlertEvaluator.resetCandidates(
            in: [snapshot],
            now: now,
            enabledProviderIDs: [.codex]).isEmpty)
    }

    @Test
    func depletionPredictionRequiresSustainedVerifiedHistory() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let candidate = UsageAlertCandidate(
            providerID: .claude,
            providerName: "Claude Code",
            windowID: "session",
            windowLabel: "5-hour",
            remainingPercent: 20,
            threshold: 30,
            resetsAt: now.addingTimeInterval(2 * 60 * 60))
        let history = [UsageHistoryRecord(
            timestamp: now.addingTimeInterval(-30 * 60),
            providerID: .claude,
            providerName: "Claude Code",
            windows: [.init(
                id: "session",
                label: "5-hour",
                remainingPercent: 40)],
            tokenTotal: nil)]

        let prediction = UsageAlertEvaluator.depletionPrediction(
            for: candidate,
            history: history,
            now: now)

        #expect(prediction?.exhaustsBeforeReset == true)
        #expect(prediction?.estimatedExhaustionAt
            == now.addingTimeInterval(30 * 60))
        #expect(UsageAlertEvaluator.depletionPrediction(
            for: candidate,
            history: history,
            now: now.addingTimeInterval(-20 * 60)) == nil)
    }

    @Test
    func usageHistoryThrottlesSamplesAndPrunesOldRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UsageHistoryStore(
            fileURL: file,
            retentionDays: 30,
            minimumRecordInterval: 15 * 60)
        let descriptor = ProviderDescriptor(
            id: .codex,
            displayName: "Codex",
            shortName: "Codex",
            systemImage: "chart.bar",
            capabilities: .init(supportsQuotaWindows: true))
        let snapshot = ProviderSnapshot(
            descriptor: descriptor,
            availability: .available,
            source: .officialAPI,
            quotaWindows: [
                QuotaWindow(id: "weekly", kind: .weekly, label: "Weekly", usedPercent: 20),
            ],
            tokenUsage: TokenUsage(label: "Session", totalTokens: 123))
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        try await store.record([snapshot], at: start)
        try await store.record([snapshot], at: start.addingTimeInterval(5 * 60))
        try await store.record([snapshot], at: start.addingTimeInterval(16 * 60))
        let throttledRecords = try await store.records()
        #expect(throttledRecords.count == 2)

        try await store.record([snapshot], at: start.addingTimeInterval(31 * 24 * 60 * 60))
        let records = try await store.records()
        #expect(records.count == 1)
        #expect(records[0].windows[0].remainingPercent == 80)
        #expect(records[0].tokenTotal == 123)

        let reloadedStore = UsageHistoryStore(fileURL: file)
        let reloadedRecords = try await reloadedStore.records()
        #expect(reloadedRecords == records)
    }

    @Test
    func exchangeRateUsesSameDayCachedQuote() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "rate.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let checkedAt = Date(timeIntervalSince1970: 1_784_240_000)
        let expected = ExchangeRateQuote(
            baseCurrency: "USD",
            quoteCurrency: "KRW",
            rate: 1479.45,
            rateDate: "2026-07-16",
            checkedAt: checkedAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(expected).write(to: file)

        let client = DailyExchangeRateClient(cacheURL: file)
        let quote = try await client.quote(at: checkedAt.addingTimeInterval(60 * 60))

        #expect(quote == expected)
    }

    @Test
    func claudeShowsConnectedWhenTodaySessionHasNoUsageYet() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let projects = temporaryHome.appending(path: ".claude/projects/test", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        let session = projects.appending(path: "session.jsonl")
        try Data("{\"timestamp\":\"2026-07-17T06:42:00Z\",\"type\":\"user\"}\n".utf8).write(to: session)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        let snapshot = await ClaudeUsageProvider(
            homeDirectory: temporaryHome,
            calendar: calendar,
            allowKeychain: false).fetchUsage()

        #expect(snapshot.availability == .available)
        #expect(snapshot.tokenUsage?.totalTokens == 0)
        #expect(snapshot.growthUsageObservation?.scope == .daily)
        #expect(snapshot.growthUsageObservation?.totalTokens == 0)
    }

    @Test
    func claudeOAuthMapsSessionWeeklyAndScopedLimits() throws {
        let file = try #require(Bundle.module.url(
            forResource: "claude-oauth-usage",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let data = try Data(contentsOf: file)
        let response = try JSONDecoder().decode(ClaudeOAuthUsageResponse.self, from: data)
        let windows = response.quotaWindows()
        let snapshot = ProviderSnapshot(
            descriptor: ClaudeUsageProvider().descriptor,
            availability: .available,
            source: .officialAPI,
            quotaWindows: windows)

        #expect(windows.map(\.label) == ["5-hour", "Weekly", "Fable weekly"])
        #expect(windows.map(\.id) == ["five-hour", "seven-day", "scoped-weekly-fable"])
        #expect(windows.map(\.usedPercent) == [12, 34, 25])
        #expect(windows.allSatisfy { $0.resetsAt != nil })
        #expect(UsageSummary.remainingPercent(
            in: [snapshot],
            for: .claude,
            windowID: "five-hour") == 88)
        #expect(UsageSummary.remainingPercent(
            in: [snapshot],
            for: .claude,
            windowID: "seven-day") == 66)
        #expect(UsageSummary.remainingPercent(
            in: [snapshot],
            for: .claude,
            windowID: "scoped-weekly-fable") == 75)
        #expect(UsageSummary.remainingPercent(
            in: [snapshot],
            for: .claude,
            windowID: "missing-window") == nil)
    }

    @Test
    func claudeCredentialParserNeverNeedsToExposeToken() throws {
        let data = Data(#"{"claudeAiOauth":{"accessToken":"fake-access-token","expiresAt":4102444800000,"rateLimitTier":"default_claude_max_5x","subscriptionType":"max"}}"#.utf8)
        let credentials = try ClaudeOAuthCredentials.decode(data)

        #expect(credentials.subscriptionType == "max")
        #expect(credentials.rateLimitTier == "default_claude_max_5x")
        #expect(!credentials.isExpired)
    }

    @Test
    func claudeBackgroundKeychainQuerySuppressesAuthenticationUI() {
        let background = ClaudeOAuthCredentialLoader.keychainQuery(interactive: false)
        let interactive = ClaudeOAuthCredentialLoader.keychainQuery(interactive: true)

        let backgroundContext = background[kSecUseAuthenticationContext] as? LAContext
        #expect(backgroundContext?.interactionNotAllowed == true)
        #expect(background[kSecUseAuthenticationUI] as? CFString == kSecUseAuthenticationUISkip)
        #expect(interactive[kSecUseAuthenticationContext] == nil)
        #expect(interactive[kSecUseAuthenticationUI] == nil)
    }

    @Test
    func claudeCredentialCacheKeepsValidCredentialsAndDropsExpiredOnes() async {
        let cache = ClaudeOAuthCredentialCache()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let valid = ClaudeOAuthCredentials(
            accessToken: "fake-valid-token",
            expiresAt: now.addingTimeInterval(60),
            rateLimitTier: nil,
            subscriptionType: "max")
        let expired = ClaudeOAuthCredentials(
            accessToken: "fake-expired-token",
            expiresAt: now.addingTimeInterval(-1),
            rateLimitTier: nil,
            subscriptionType: "max")

        await cache.store(valid)
        #expect(await cache.value(at: now)?.accessToken == "fake-valid-token")
        await cache.store(expired)
        #expect(await cache.value(at: now) == nil)
    }
}
