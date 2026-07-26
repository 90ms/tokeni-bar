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
    private let credentialLoader: CodexAccountCredentialLoader
    private let accountClient: CodexAccountUsageClient
    private let accountTokenUsageClient: CodexAccountTokenUsageClient
    private let resetCreditsClient: CodexResetCreditsClient

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.sessionsDirectory = homeDirectory.appending(path: ".codex/sessions", directoryHint: .isDirectory)
        self.credentialLoader = CodexAccountCredentialLoader(homeDirectory: homeDirectory)
        self.accountClient = CodexAccountUsageClient()
        self.accountTokenUsageClient = CodexAccountTokenUsageClient()
        self.resetCreditsClient = CodexResetCreditsClient()
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let localUsage = self.latestLocalUsage()
        async let accountTokenUsageFetch = try? self.accountTokenUsageClient.fetch()

        do {
            let credentials = try self.credentialLoader.load()
            async let resetCreditsFetch = try? self.resetCreditsClient.fetch(credentials: credentials)
            let result = try await self.accountClient.fetch(credentials: credentials)
            let resetCreditsResult = await resetCreditsFetch
            let accountTokenUsageResult = await accountTokenUsageFetch
            let resetCredits = resetCreditsResult?.response.summary()
            let accountTokenUsage = self.accountTokenUsage(from: accountTokenUsageResult)
            let referenceCost = self.referenceCost(for: accountTokenUsage)
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
                tokenUsage: accountTokenUsage.map {
                    TokenUsage(label: "This month · account", totalTokens: $0.currentMonthTokens)
                },
                costEstimate: referenceCost,
                accountTokenUsage: accountTokenUsage,
                credits: accountUsage.creditBalance,
                quotaResetCredits: resetCredits,
                detail: detail,
                updatedAt: max(result.fetchedAt, accountTokenUsageResult?.fetchedAt ?? .distantPast))
        } catch {
            let accountTokenUsageResult = await accountTokenUsageFetch
            return self.localFallback(
                localUsage: localUsage,
                accountTokenUsageResult: accountTokenUsageResult,
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

    private func localFallback(
        localUsage: CodexParsedUsage?,
        accountTokenUsageResult: CodexAccountTokenUsageResult?,
        accountError: Error) -> ProviderSnapshot
    {
        let errorMessage = (accountError as? LocalizedError)?.errorDescription
        let accountTokenUsage = self.accountTokenUsage(from: accountTokenUsageResult)
        let referenceCost = self.referenceCost(for: accountTokenUsage)
        if localUsage != nil || accountTokenUsage != nil {
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: accountTokenUsage == nil ? .localSessionLog : .localProtocol,
                quotaWindows: localUsage?.quotaWindows ?? [],
                tokenUsage: accountTokenUsage.map {
                    TokenUsage(label: "This month · account", totalTokens: $0.currentMonthTokens)
                },
                costEstimate: referenceCost,
                accountTokenUsage: accountTokenUsage,
                credits: localUsage?.credits,
                detail: errorMessage.map { "Partial Codex data · \($0)" }
                    ?? "Partial Codex data",
                updatedAt: max(
                    localUsage?.timestamp ?? .now,
                    accountTokenUsageResult?.fetchedAt ?? .distantPast))
        }
        return .init(
            descriptor: self.descriptor,
            availability: .stale,
            source: .localSessionLog,
            detail: errorMessage ?? "No Codex usage event was found in ~/.codex/sessions")
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

    private func referenceCost(
        for usage: AccountTokenUsageSummary?) -> TokenCostEstimate?
    {
        guard let usage,
              let estimator = AccountTokenReferenceCostEstimator
                .codexInputOutputReferenceV1()
        else { return nil }
        return TokenCostEstimate(
            label: "This month · API-equivalent reference",
            amountUSD: estimator.estimate(tokenCount: usage.currentMonthTokens).amountUSD,
            modelIDs: [estimator.assumption.referenceModelID])
    }
}

struct CodexParsedUsage {
    let timestamp: Date?
    let quotaWindows: [QuotaWindow]
    let tokenUsage: TokenUsage
    let credits: CreditBalance?
}

enum CodexLogParser {
    static func latestUsage(in file: URL) -> CodexParsedUsage? {
        let events = LocalFiles.lines(in: file).compactMap {
            try? JSONDecoder().decode(CodexEvent.self, from: $0)
        }
        let modelID = events.reversed().compactMap(\.payload?.model).first

        for event in events.reversed() {
            guard
                  event.type == "event_msg",
                  event.payload?.type == "token_count",
                  let usage = event.payload?.info?.totalTokenUsage
            else { continue }

            let limits = event.payload?.rateLimits
            var windows: [QuotaWindow] = []
            if let primary = limits?.primary {
                windows.append(primary.quotaWindow(id: "primary", fallbackLabel: "Session"))
            }
            if let secondary = limits?.secondary {
                windows.append(secondary.quotaWindow(id: "secondary", fallbackLabel: "Weekly"))
            }

            let credits = limits?.credits.map {
                CreditBalance(balance: $0.balance, hasCredits: $0.hasCredits, unlimited: $0.unlimited)
            }
            let tokenUsage = TokenUsage(
                label: "Latest session",
                modelID: modelID,
                inputTokens: max(usage.inputTokens - usage.cachedInputTokens, 0),
                cachedInputTokens: usage.cachedInputTokens,
                outputTokens: max(usage.outputTokens - usage.reasoningOutputTokens, 0),
                reasoningTokens: usage.reasoningOutputTokens,
                totalTokens: usage.totalTokens)
            return CodexParsedUsage(
                timestamp: TimestampParser.parse(event.timestamp),
                quotaWindows: windows,
                tokenUsage: tokenUsage,
                credits: credits)
        }
        return nil
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
