import Foundation

public struct CodexUsageProvider: UsageProviding, UsageActivityProviding,
    UsageAuthorizationProviding, UsageCacheInvalidating
{
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
    private let accountClient: CodexAccountUsageClient
    private let accountTokenUsageClient: CodexAccountTokenUsageClient
    private let localUsageCache: CodexLocalUsageCache

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current,
        codexHomeDirectory: URL? = nil)
    {
        let codexHomeDirectory = Self.resolvedCodexHomeDirectory(
            homeDirectory: homeDirectory,
            explicitDirectory: codexHomeDirectory,
            environment: ProcessInfo.processInfo.environment)
        self.sessionsDirectory = codexHomeDirectory.appending(
            path: "sessions",
            directoryHint: .isDirectory)
        self.calendar = calendar
        self.accountClient = CodexAccountUsageClient(homeDirectory: homeDirectory)
        self.accountTokenUsageClient = CodexAccountTokenUsageClient(
            homeDirectory: homeDirectory)
        self.localUsageCache = CodexLocalUsageCache()
    }

    static func resolvedCodexHomeDirectory(
        homeDirectory: URL,
        explicitDirectory: URL?,
        environment: [String: String]) -> URL
    {
        if let explicitDirectory {
            return explicitDirectory
        }
        if let path = environment["CODEX_HOME"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return homeDirectory.appending(
            path: ".codex",
            directoryHint: .isDirectory)
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let latestLocalUsage = await self.latestLocalUsage()
        let todayUsage = await self.todayLocalUsage()
        async let accountTokenUsageTask = self.fetchAccountTokenUsage()

        do {
            let result = try await self.accountClient.fetch()
            let accountTokenUsageFetch = await accountTokenUsageTask
            let accountTokenUsageResult = accountTokenUsageFetch.result
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
            let detail = [plan, "Codex CLI account usage"]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .cli,
                quotaWindows: accountUsage.quotaWindows(),
                tokenUsage: todayUsage?.tokenUsage,
                costEstimate: todayUsage?.costEstimate,
                accountTokenUsage: accountTokenUsage,
                accountTokenUsageIssue: accountTokenUsageFetch.issue,
                credits: accountUsage.creditBalance,
                quotaResetCredits: result.quotaResetCredits,
                growthUsageObservation: growthObservation,
                connectionState: .connected,
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
        await self.localUsageCache.invalidate()
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.sessionsDirectory,
            modifiedAfter: cutoff,
            matching: { $0.pathExtension == "jsonl" })
    }

    private func latestLocalUsage() async -> CodexParsedUsage? {
        let files = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            extension: "jsonl",
            limit: 16)
        return await self.localUsageCache.latestUsage(files: files)
    }

    private func todayLocalUsage() async -> CodexTodayUsage? {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let files = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            extension: "jsonl",
            modifiedAfter: startOfDay,
            limit: 512)
        return await self.localUsageCache.todayUsage(
            files: files,
            since: startOfDay)
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
                connectionState: self.connectionState(for: accountError),
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
            connectionState: self.connectionState(for: accountError),
            detail: errorMessage
                ?? "No Codex usage event was found in \(self.sessionsDirectory.path)")
    }

    public func requestUsageAuthorization() async throws {
        _ = try await self.accountClient.fetch(forceRefresh: true)
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

    private func connectionState(for error: Error) -> ProviderConnectionState {
        guard let error = error as? CodexCLIUsageError else { return .localOnly }
        switch error {
        case .accountUnavailable:
            return .authorizationRequired
        default:
            return .localOnly
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

actor CodexLocalUsageCache {
    private var latestSignatures: [LocalFileSignature]?
    private var latestResult: CodexParsedUsage?
    private var hasLatestResult = false
    private var todaySignatures: [LocalFileSignature]?
    private var todayStartDate: Date?
    private var todayResult: CodexTodayUsage?
    private var hasTodayResult = false

    func latestUsage(files: [URL]) -> CodexParsedUsage? {
        let nextSignatures = LocalFiles.signatures(for: files)
        if self.latestSignatures == nextSignatures, self.hasLatestResult {
            return self.latestResult
        }

        var parsed: CodexParsedUsage?
        for file in files {
            if let latest = CodexLogParser.latestUsage(in: file) {
                parsed = latest
                break
            }
        }
        self.latestSignatures = nextSignatures
        self.latestResult = parsed
        self.hasLatestResult = true
        return parsed
    }

    func todayUsage(files: [URL], since startDate: Date) -> CodexTodayUsage? {
        let nextSignatures = LocalFiles.signatures(for: files)
        if self.todaySignatures == nextSignatures,
           self.todayStartDate == startDate,
           self.hasTodayResult
        {
            return self.todayResult
        }

        let result = CodexTodayLogParser.aggregate(
            files: files,
            since: startDate)
        self.todaySignatures = nextSignatures
        self.todayStartDate = startDate
        self.todayResult = result
        self.hasTodayResult = true
        return result
    }

    func invalidate() {
        self.latestSignatures = nil
        self.latestResult = nil
        self.hasLatestResult = false
        self.todaySignatures = nil
        self.todayStartDate = nil
        self.todayResult = nil
        self.hasTodayResult = false
    }
}

struct CodexParsedUsage: Sendable {
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
