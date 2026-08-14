import Foundation

public struct CodexUsageProvider: UsageProviding, UsageActivityProviding, UsageCacheInvalidating {
    public let descriptor = ProviderDescriptor(
        id: .codex,
        displayName: "Codex",
        shortName: "Codex",
        systemImage: "chevron.left.forwardslash.chevron.right",
        iconAssetName: "openai",
        capabilities: .init(
            supportsQuotaWindows: true,
            supportsTokenUsage: true,
            supportsCredits: true))

    private let sessionsDirectory: URL
    private let calendar: Calendar
    private let credentialLoader: CodexAccountCredentialLoader
    private let accountClient: CodexAccountUsageClient
    private let accountTokenUsageClient: CodexAccountTokenUsageClient
    private let resetCreditsClient: CodexResetCreditsClient

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current)
    {
        self.sessionsDirectory = homeDirectory.appending(path: ".codex/sessions", directoryHint: .isDirectory)
        self.calendar = calendar
        self.credentialLoader = CodexAccountCredentialLoader(homeDirectory: homeDirectory)
        self.accountClient = CodexAccountUsageClient()
        self.accountTokenUsageClient = CodexAccountTokenUsageClient(
            homeDirectory: homeDirectory)
        self.resetCreditsClient = CodexResetCreditsClient()
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let latestLocalUsage = self.latestLocalUsage()
        let todayUsage = self.todayLocalUsage()
        async let accountTokenUsageTask = self.fetchAccountTokenUsage()

        do {
            let credentials = try self.credentialLoader.load()
            async let resetCreditsFetch = try? self.resetCreditsClient.fetch(credentials: credentials)
            let result = try await self.accountClient.fetch(credentials: credentials)
            let resetCreditsResult = await resetCreditsFetch
            let accountTokenUsageFetch = await accountTokenUsageTask
            let accountTokenUsageResult = accountTokenUsageFetch.result
            let resetCredits = resetCreditsResult?.response.summary()
            let accountTokenUsage = self.accountTokenUsage(from: accountTokenUsageResult)
            let growthObservation = self.growthObservation(
                todayUsage: todayUsage,
                accountUsage: accountTokenUsage,
                accountObservedAt: accountTokenUsageResult?.fetchedAt,
                localUsage: latestLocalUsage)
            let accountUsage = result.response
            let plan = accountUsage.planType?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            let detail = [plan, "Codex account usage"]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .officialAPI,
                quotaWindows: accountUsage.quotaWindows(),
                tokenUsage: todayUsage?.tokenUsage,
                costEstimate: todayUsage?.costEstimate,
                accountTokenUsage: accountTokenUsage,
                accountTokenUsageIssue: accountTokenUsageFetch.issue,
                credits: accountUsage.creditBalance,
                quotaResetCredits: resetCredits,
                growthUsageObservation: growthObservation,
                detail: todayUsage.map {
                    "\(detail) · today across \($0.sessionCount) local sessions"
                } ?? detail,
                updatedAt: max(
                    todayUsage?.observedAt ?? .distantPast,
                    max(result.fetchedAt, accountTokenUsageResult?.fetchedAt ?? .distantPast)))
        } catch {
            let accountTokenUsageFetch = await accountTokenUsageTask
            return self.localFallback(
                latestLocalUsage: latestLocalUsage,
                todayUsage: todayUsage,
                accountTokenUsageResult: accountTokenUsageFetch.result,
                accountTokenUsageIssue: accountTokenUsageFetch.issue,
                accountError: error)
        }
    }

    public func invalidateUsageCache() async {
        await self.accountClient.invalidateCache()
        await self.accountTokenUsageClient.invalidateCache()
        await self.resetCreditsClient.invalidateCache()
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.sessionsDirectory,
            modifiedAfter: cutoff,
            matching: { $0.pathExtension == "jsonl" })
    }

    private func latestLocalUsage() -> CodexParsedUsage? {
        let files = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            extension: "jsonl",
            limit: 16)

        for file in files {
            if let parsed = CodexLogParser.latestUsage(in: file) {
                return parsed
            }
        }
        return nil
    }

    private func todayLocalUsage() -> CodexTodayUsage? {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let files = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            extension: "jsonl",
            modifiedAfter: startOfDay,
            limit: 512)
        return CodexTodayLogParser.aggregate(files: files, since: startOfDay)
    }

    private func localFallback(
        latestLocalUsage: CodexParsedUsage?,
        todayUsage: CodexTodayUsage?,
        accountTokenUsageResult: CodexAccountTokenUsageResult?,
        accountTokenUsageIssue: AccountTokenUsageIssue?,
        accountError: Error) -> ProviderSnapshot
    {
        let errorMessage = (accountError as? LocalizedError)?.errorDescription
        let accountTokenUsage = self.accountTokenUsage(from: accountTokenUsageResult)
        let growthObservation = self.growthObservation(
            todayUsage: todayUsage,
            accountUsage: accountTokenUsage,
            accountObservedAt: accountTokenUsageResult?.fetchedAt,
            localUsage: latestLocalUsage)
        if latestLocalUsage != nil || todayUsage != nil || accountTokenUsage != nil {
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: accountTokenUsage == nil ? .localSessionLog : .localProtocol,
                quotaWindows: latestLocalUsage?.quotaWindows ?? [],
                tokenUsage: todayUsage?.tokenUsage,
                costEstimate: todayUsage?.costEstimate,
                accountTokenUsage: accountTokenUsage,
                accountTokenUsageIssue: accountTokenUsageIssue,
                credits: latestLocalUsage?.credits,
                growthUsageObservation: growthObservation,
                detail: errorMessage.map { "Partial Codex data · \($0)" }
                    ?? "Partial Codex data",
                updatedAt: max(
                    todayUsage?.observedAt ?? latestLocalUsage?.timestamp ?? .now,
                    accountTokenUsageResult?.fetchedAt ?? .distantPast))
        }
        return .init(
            descriptor: self.descriptor,
            availability: .stale,
            source: .localSessionLog,
            accountTokenUsageIssue: accountTokenUsageIssue,
            detail: errorMessage ?? "No Codex usage event was found in ~/.codex/sessions")
    }

    private func fetchAccountTokenUsage() async -> (
        result: CodexAccountTokenUsageResult?,
        issue: AccountTokenUsageIssue?)
    {
        do {
            return (try await self.accountTokenUsageClient.fetch(), nil)
        } catch let error as CodexAccountTokenUsageError {
            let issue: AccountTokenUsageIssue = switch error {
            case .executableUnavailable:
                .executableUnavailable
            case .accountUnavailable:
                .signInRequired
            case .unsupported:
                .unsupported
            case .launchFailed, .timedOut, .server(_), .invalidResponse:
                .failed
            }
            return (nil, issue)
        } catch {
            return (nil, .failed)
        }
    }

    private func accountTokenUsage(
        from result: CodexAccountTokenUsageResult?) -> AccountTokenUsageSummary?
    {
        guard let response = result?.response,
              let lifetimeTokens = response.summary.lifetimeTokens,
              let dailyBuckets = response.dailyUsageBuckets
        else { return nil }
        return AccountTokenUsageAggregator.summarize(
            dailyBuckets: dailyBuckets.map {
                AccountDailyTokenBucket(startDate: $0.startDate, tokenCount: $0.tokens)
            },
            lifetimeTokens: lifetimeTokens)
    }

    func growthObservation(
        todayUsage: CodexTodayUsage? = nil,
        accountUsage: AccountTokenUsageSummary?,
        accountObservedAt: Date?,
        localUsage: CodexParsedUsage?) -> GrowthUsageObservation?
    {
        if let todayUsage {
            return .daily(
                providerID: .codex,
                dateKey: GrowthLocalDate.key(
                    for: todayUsage.observedAt,
                    calendar: self.calendar),
                totalTokens: todayUsage.tokenUsage.totalTokens,
                observedAt: todayUsage.observedAt)
        }
        if let accountUsage,
           let latestBucketDate = accountUsage.latestBucketDate,
           let latestDailyTokens = accountUsage.latestDailyTokens
        {
            return .daily(
                providerID: .codex,
                dateKey: latestBucketDate,
                totalTokens: latestDailyTokens,
                observedAt: accountObservedAt ?? .now)
        }
        guard let localUsage else { return nil }
        return GrowthUsageObservation(
            providerID: .codex,
            scope: .session,
            scopeID: localUsage.sessionID,
            totalTokens: localUsage.tokenUsage.totalTokens,
            observedAt: localUsage.timestamp ?? .now)
    }
}

struct CodexParsedUsage {
    let sessionID: String
    let timestamp: Date?
    let quotaWindows: [QuotaWindow]
    let tokenUsage: TokenUsage
    let credits: CreditBalance?
}

enum CodexLogParser {
    static func latestUsage(in file: URL) -> CodexParsedUsage? {
        let decoder = JSONDecoder()
        var latestModelID: String?
        var latestTokenEvent: CodexEvent?
        guard LocalFiles.forEachLine(in: file, { line in
            guard let event = try? decoder.decode(CodexEvent.self, from: line)
            else { return }
            if let modelID = event.payload?.model {
                latestModelID = modelID
            }
            if event.type == "event_msg",
               event.payload?.type == "token_count",
               event.payload?.info?.totalTokenUsage != nil
            {
                latestTokenEvent = event
            }
        }),
        let event = latestTokenEvent,
        let usage = event.payload?.info?.totalTokenUsage
        else { return nil }

        let limits = event.payload?.rateLimits
        var windows: [QuotaWindow] = []
        if let primary = limits?.primary {
            windows.append(primary.quotaWindow(
                id: "primary",
                fallbackLabel: "Session"))
        }
        if let secondary = limits?.secondary {
            windows.append(secondary.quotaWindow(
                id: "secondary",
                fallbackLabel: "Weekly"))
        }

        let credits = limits?.credits.map {
            CreditBalance(
                balance: $0.balance,
                hasCredits: $0.hasCredits,
                unlimited: $0.unlimited)
        }
        let tokenUsage = TokenUsage(
            label: "Latest session",
            modelID: latestModelID,
            inputTokens: max(usage.inputTokens - usage.cachedInputTokens, 0),
            cachedInputTokens: usage.cachedInputTokens,
            outputTokens: max(
                usage.outputTokens - usage.reasoningOutputTokens,
                0),
            reasoningTokens: usage.reasoningOutputTokens,
            totalTokens: usage.totalTokens)
        return CodexParsedUsage(
            sessionID: file.deletingPathExtension().lastPathComponent,
            timestamp: TimestampParser.parse(event.timestamp),
            quotaWindows: windows,
            tokenUsage: tokenUsage,
            credits: credits)
    }
}

private struct CodexEvent: Decodable {
    let timestamp: String?
    let type: String
    let payload: Payload?

    struct Payload: Decodable {
        let type: String?
        let model: String?
        let info: Info?
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case type, model, info
            case rateLimits = "rate_limits"
        }
    }

    struct Info: Decodable {
        let totalTokenUsage: TokenBreakdown?

        enum CodingKeys: String, CodingKey {
            case totalTokenUsage = "total_token_usage"
        }
    }

    struct TokenBreakdown: Decodable {
        let inputTokens: Int64
        let cachedInputTokens: Int64
        let outputTokens: Int64
        let reasoningOutputTokens: Int64
        let totalTokens: Int64

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case outputTokens = "output_tokens"
            case reasoningOutputTokens = "reasoning_output_tokens"
            case totalTokens = "total_tokens"
        }
    }

    struct RateLimits: Decodable {
        let primary: LimitWindow?
        let secondary: LimitWindow?
        let credits: Credits?
    }

    struct LimitWindow: Decodable {
        let usedPercent: Double
        let windowMinutes: Int?
        let resetsAt: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
        }

        func quotaWindow(id: String, fallbackLabel: String) -> QuotaWindow {
            let kind: QuotaWindowKind
            let label: String
            if let windowMinutes, windowMinutes >= 7 * 24 * 60 {
                kind = .weekly
                label = "Weekly"
            } else {
                kind = id == "primary" ? .session : .custom
                label = fallbackLabel
            }
            return QuotaWindow(
                id: id,
                kind: kind,
                label: label,
                usedPercent: self.usedPercent,
                resetsAt: self.resetsAt.map(Date.init(timeIntervalSince1970:)),
                durationMinutes: self.windowMinutes)
        }
    }

    struct Credits: Decodable {
        let balance: String?
        let hasCredits: Bool
        let unlimited: Bool

        enum CodingKeys: String, CodingKey {
            case balance
            case hasCredits = "has_credits"
            case unlimited
        }
    }
}
