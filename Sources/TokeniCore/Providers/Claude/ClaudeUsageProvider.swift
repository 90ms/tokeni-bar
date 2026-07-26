import Foundation

public struct ClaudeUsageProvider: UsageProviding, UsageActivityProviding,
    UsageAuthorizationProviding, UsageCacheInvalidating
{
    public let descriptor = ProviderDescriptor(
        id: .claude,
        displayName: "Claude Code",
        shortName: "Claude",
        systemImage: "sparkles",
        iconAssetName: "claude",
        capabilities: .init(supportsTokenUsage: true))

    private let projectsDirectory: URL
    private let calendar: Calendar
    private let credentialLoader: ClaudeOAuthCredentialLoader
    private let credentialCache: ClaudeOAuthCredentialCache
    private let oauthClient: ClaudeOAuthUsageClient

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current,
        allowKeychain: Bool = true)
    {
        self.projectsDirectory = homeDirectory.appending(path: ".claude/projects", directoryHint: .isDirectory)
        self.calendar = calendar
        self.credentialLoader = ClaudeOAuthCredentialLoader(
            homeDirectory: homeDirectory,
            allowKeychain: allowKeychain)
        self.credentialCache = ClaudeOAuthCredentialCache()
        self.oauthClient = ClaudeOAuthUsageClient()
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let files = LocalFiles.newestFiles(
            below: self.projectsDirectory,
            extension: "jsonl",
            modifiedAfter: startOfDay,
            limit: 200)
        let aggregate = ClaudeLogParser.aggregate(files: files, since: startOfDay)
        let usage = aggregate.tokenUsage
        let localTokenUsage = usage.totalTokens > 0
            ? usage
            : files.isEmpty ? nil : TokenUsage(label: "Today", totalTokens: 0)

        do {
            let credentials = try await self.credentials(interactive: false)
            let result = try await self.oauthClient.fetch(accessToken: credentials.accessToken)
            let oauthUsage = result.response
            let plan = credentials.subscriptionType ?? credentials.rateLimitTier
            let detail = [plan, "Claude Code OAuth"]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .officialAPI,
                quotaWindows: oauthUsage.quotaWindows(),
                tokenUsage: localTokenUsage,
                costEstimate: localTokenUsage == nil ? nil : aggregate.costEstimate,
                detail: detail.isEmpty ? "Claude Code OAuth" : detail,
                updatedAt: result.fetchedAt)
        } catch {
            if case ClaudeOAuthUsageError.unauthorized = error {
                await self.credentialCache.invalidate()
            }
            return self.localFallback(files: files, aggregate: aggregate, oauthError: error)
        }
    }

    public func requestUsageAuthorization() async throws {
        _ = try await self.credentials(interactive: true)
        await self.oauthClient.invalidateCache()
    }

    public func invalidateUsageCache() async {
        await self.oauthClient.invalidateCache()
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.projectsDirectory,
            modifiedAfter: cutoff,
            matching: { $0.pathExtension == "jsonl" })
    }

    private func credentials(interactive: Bool) async throws -> ClaudeOAuthCredentials {
        if let cached = await self.credentialCache.value() {
            return cached
        }
        let credentials = try self.credentialLoader.load(interactive: interactive)
        await self.credentialCache.store(credentials)
        return credentials
    }

    private func localFallback(
        files: [URL],
        aggregate: ClaudeAggregatedUsage,
        oauthError: Error) -> ProviderSnapshot
    {
        let usage = aggregate.tokenUsage
        let errorMessage = (oauthError as? LocalizedError)?.errorDescription
        guard !files.isEmpty else {
            return .init(
                descriptor: self.descriptor,
                availability: .stale,
                source: .localSessionLog,
                detail: errorMessage ?? "Claude Code is installed, but no local session was updated today")
        }

        guard usage.totalTokens > 0 else {
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .localSessionLog,
                tokenUsage: TokenUsage(label: "Today", totalTokens: 0),
                detail: errorMessage.map { "Connected · \($0)" }
                    ?? "Connected · no token usage record in today's session yet")
        }

        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            tokenUsage: usage,
            costEstimate: aggregate.costEstimate,
            detail: errorMessage.map { "Local usage fallback · \($0)" }
                ?? "Today across local Claude Code sessions")
    }
}

struct ClaudeAggregatedUsage {
    let tokenUsage: TokenUsage
    let costEstimate: TokenCostEstimate?
}

enum ClaudeLogParser {
    static func aggregate(files: [URL], since startDate: Date) -> ClaudeAggregatedUsage {
        var seenMessageIDs: Set<String> = []
        var input: Int64 = 0
        var cacheCreation: Int64 = 0
        var cacheCreation1h: Int64 = 0
        var cached: Int64 = 0
        var output: Int64 = 0
        var amountUSD = 0.0
        var modelIDs: Set<String> = []
        var allRecordsPriced = true
        var recordCount = 0

        for file in files {
            for line in LocalFiles.lines(in: file) {
                guard let record = try? JSONDecoder().decode(ClaudeRecord.self, from: line),
                      let usage = record.message?.usage,
                      let timestamp = TimestampParser.parse(record.timestamp),
                      timestamp >= startDate
                else { continue }

                let identifier = record.message?.id ?? record.uuid ?? "\(file.path):\(record.timestamp ?? "")"
                guard seenMessageIDs.insert(identifier).inserted else { continue }
                recordCount += 1
                input += usage.inputTokens
                let oneHourCacheCreation = usage.cacheCreation?.ephemeral1hInputTokens ?? 0
                let fiveMinuteCacheCreation = max(
                    usage.cacheCreationInputTokens - oneHourCacheCreation,
                    0)
                cacheCreation += fiveMinuteCacheCreation
                cacheCreation1h += oneHourCacheCreation
                cached += usage.cacheReadInputTokens
                output += usage.outputTokens
                if let modelID = record.message?.model,
                   let pricing = TokenPricingCatalog.pricing(
                       providerID: .claude,
                       modelID: modelID,
                       at: timestamp)
                {
                    modelIDs.insert(modelID)
                    amountUSD += pricing.estimate(TokenUsage(
                        label: "Today",
                        modelID: modelID,
                        inputTokens: usage.inputTokens,
                        cacheCreationInputTokens: fiveMinuteCacheCreation,
                        cacheCreation1hInputTokens: oneHourCacheCreation,
                        cachedInputTokens: usage.cacheReadInputTokens,
                        outputTokens: usage.outputTokens,
                        totalTokens: usage.inputTokens + usage.cacheCreationInputTokens
                            + usage.cacheReadInputTokens + usage.outputTokens))
                } else {
                    allRecordsPriced = false
                }
            }
        }

        let tokenUsage = TokenUsage(
            label: "Today",
            modelID: modelIDs.count == 1 ? modelIDs.first : nil,
            inputTokens: input,
            cacheCreationInputTokens: cacheCreation,
            cacheCreation1hInputTokens: cacheCreation1h,
            cachedInputTokens: cached,
            outputTokens: output,
            totalTokens: input + cacheCreation + cacheCreation1h + cached + output)
        let estimate = recordCount > 0 && allRecordsPriced
            ? TokenCostEstimate(
                label: "Today",
                amountUSD: amountUSD,
                modelIDs: modelIDs.sorted())
            : nil
        return ClaudeAggregatedUsage(tokenUsage: tokenUsage, costEstimate: estimate)
    }
}

private struct ClaudeRecord: Decodable {
    let uuid: String?
    let timestamp: String?
    let message: Message?

    struct Message: Decodable {
        let id: String?
        let model: String?
        let usage: Usage?
    }

    struct Usage: Decodable {
        let inputTokens: Int64
        let cacheCreationInputTokens: Int64
        let cacheReadInputTokens: Int64
        let outputTokens: Int64
        let cacheCreation: CacheCreation?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreation = "cache_creation"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.inputTokens = try container.decodeIfPresent(Int64.self, forKey: .inputTokens) ?? 0
            self.cacheCreationInputTokens = try container.decodeIfPresent(
                Int64.self,
                forKey: .cacheCreationInputTokens) ?? 0
            self.cacheReadInputTokens = try container.decodeIfPresent(
                Int64.self,
                forKey: .cacheReadInputTokens) ?? 0
            self.outputTokens = try container.decodeIfPresent(Int64.self, forKey: .outputTokens) ?? 0
            self.cacheCreation = try container.decodeIfPresent(
                CacheCreation.self,
                forKey: .cacheCreation)
        }
    }

    struct CacheCreation: Decodable {
        let ephemeral1hInputTokens: Int64

        enum CodingKeys: String, CodingKey {
            case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.ephemeral1hInputTokens = try container.decodeIfPresent(
                Int64.self,
                forKey: .ephemeral1hInputTokens) ?? 0
        }
    }
}
