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
        capabilities: .init(
            supportsQuotaWindows: true,
            supportsTokenUsage: true))

    private let projectsDirectory: URL
    private let calendar: Calendar
    private let cliClient: ClaudeCLIUsageClient
    private let localUsageCache: ClaudeLocalUsageCache

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current,
        configDirectory: URL? = nil)
    {
        let configDirectory = Self.resolvedConfigDirectory(
            homeDirectory: homeDirectory,
            explicitDirectory: configDirectory,
            environment: ProcessInfo.processInfo.environment)
        self.init(
            homeDirectory: homeDirectory,
            calendar: calendar,
            cliClient: ClaudeCLIUsageClient(homeDirectory: homeDirectory),
            configDirectory: configDirectory)
    }

    init(
        homeDirectory: URL,
        calendar: Calendar,
        cliClient: ClaudeCLIUsageClient,
        configDirectory: URL? = nil,
        localUsageCache: ClaudeLocalUsageCache = ClaudeLocalUsageCache())
    {
        let configDirectory = configDirectory
            ?? homeDirectory.appending(path: ".claude", directoryHint: .isDirectory)
        self.projectsDirectory = configDirectory.appending(
            path: "projects",
            directoryHint: .isDirectory)
        self.calendar = calendar
        self.cliClient = cliClient
        self.localUsageCache = localUsageCache
    }

    static func resolvedConfigDirectory(
        homeDirectory: URL,
        explicitDirectory: URL?,
        environment: [String: String]) -> URL
    {
        if let explicitDirectory {
            return explicitDirectory
        }
        if let path = environment["CLAUDE_CONFIG_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return homeDirectory.appending(path: ".claude", directoryHint: .isDirectory)
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let files = LocalFiles.newestFiles(
            below: self.projectsDirectory,
            extension: "jsonl",
            modifiedAfter: startOfDay,
            limit: 200)
        let aggregate = await self.localUsageCache.aggregate(
            files: files,
            since: startOfDay)
        let usage = aggregate?.tokenUsage
        let localTokenUsage = files.isEmpty ? nil : usage.map {
            $0.totalTokens > 0
                ? $0
                : TokenUsage(label: "Today", totalTokens: 0)
        }
        let observedAt = Date.now
        let growthObservation = localTokenUsage.map {
            GrowthUsageObservation.daily(
                providerID: .claude,
                dateKey: GrowthLocalDate.key(for: observedAt, calendar: self.calendar),
                totalTokens: $0.totalTokens,
                observedAt: observedAt)
        }

        do {
            let result = try await self.cliClient.fetch()
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .cli,
                quotaWindows: result.response.quotaWindows,
                tokenUsage: localTokenUsage,
                costEstimate: localTokenUsage == nil ? nil : aggregate?.costEstimate,
                growthUsageObservation: growthObservation,
                connectionState: .connected,
                detail: "Claude Code CLI",
                updatedAt: result.fetchedAt)
        } catch {
            let fallback = await self.fallbackContext(for: error)
            return self.localFallback(
                files: files,
                aggregate: aggregate,
                growthObservation: growthObservation,
                cliError: fallback.error,
                connectionState: fallback.connectionState)
        }
    }

    public func requestUsageAuthorization() async throws {
        try await self.cliClient.verifyAuthentication()
    }

    public func invalidateUsageCache() async {
        await self.cliClient.invalidateCache()
        await self.localUsageCache.invalidate()
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.projectsDirectory,
            modifiedAfter: cutoff,
            matching: { $0.pathExtension == "jsonl" })
    }

    private func localFallback(
        files: [URL],
        aggregate: ClaudeAggregatedUsage?,
        growthObservation: GrowthUsageObservation?,
        cliError: Error,
        connectionState overrideConnectionState: ProviderConnectionState? = nil) -> ProviderSnapshot
    {
        let errorMessage = (cliError as? LocalizedError)?.errorDescription
        let connectionState = overrideConnectionState
            ?? self.connectionState(for: cliError)
        let staleConnectionState: ProviderConnectionState =
            connectionState == .localOnly ? .stale : connectionState
        guard !files.isEmpty else {
            return .init(
                descriptor: self.descriptor,
                availability: .stale,
                source: .localSessionLog,
                connectionState: staleConnectionState,
                detail: errorMessage ?? "Claude Code is installed, but no local session was updated today")
        }

        guard let aggregate else {
            return .init(
                descriptor: self.descriptor,
                availability: .stale,
                source: .localSessionLog,
                connectionState: staleConnectionState,
                detail: errorMessage
                    ?? "Claude local usage logs are too large or could not be read safely")
        }
        let usage = aggregate.tokenUsage
        guard usage.totalTokens > 0 else {
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .localSessionLog,
                tokenUsage: TokenUsage(label: "Today", totalTokens: 0),
                growthUsageObservation: growthObservation,
                connectionState: connectionState,
                detail: errorMessage.map { "Connected · \($0)" }
                    ?? "Connected · no token usage record in today's session yet")
        }

        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            tokenUsage: usage,
            costEstimate: aggregate.costEstimate,
            growthUsageObservation: growthObservation,
            connectionState: connectionState,
            detail: errorMessage.map { "Local usage fallback · \($0)" }
                ?? "Today across local Claude Code sessions")
    }

    private func fallbackContext(for usageError: Error) async
        -> (error: Error, connectionState: ProviderConnectionState?)
    {
        do {
            try await self.cliClient.verifyAuthentication()
            return (usageError, .connected)
        } catch {
            return (error, nil)
        }
    }

    private func connectionState(
        for error: Error) -> ProviderConnectionState
    {
        guard let error = error as? ClaudeCLIUsageError else {
            return .localOnly
        }
        switch error {
        case .signInRequired:
            return .authorizationRequired
        case .sessionExpired:
            return .sessionExpired
        default:
            return .localOnly
        }
    }
}

actor ClaudeLocalUsageCache {
    private var signatures: [LocalFileSignature]?
    private var startDate: Date?
    private var cachedAggregate: ClaudeAggregatedUsage?
    private var hasCachedAggregate = false

    func aggregate(
        files: [URL],
        since startDate: Date) -> ClaudeAggregatedUsage?
    {
        let nextSignatures = LocalFiles.signatures(for: files)
        if self.signatures == nextSignatures,
           self.startDate == startDate,
           self.hasCachedAggregate
        {
            return self.cachedAggregate
        }

        let aggregate = ClaudeLogParser.aggregate(
            files: files,
            since: startDate)
        self.signatures = nextSignatures
        self.startDate = startDate
        self.cachedAggregate = aggregate
        self.hasCachedAggregate = true
        return aggregate
    }

    func invalidate() {
        self.signatures = nil
        self.startDate = nil
        self.cachedAggregate = nil
        self.hasCachedAggregate = false
    }
}

struct ClaudeAggregatedUsage: Sendable {
    let tokenUsage: TokenUsage
    let costEstimate: TokenCostEstimate?
}

enum ClaudeLogParser {
    static func aggregate(
        files: [URL],
        since startDate: Date) -> ClaudeAggregatedUsage?
    {
        guard LocalFiles.totalSize(of: files) != nil else { return nil }
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
        let decoder = JSONDecoder()

        for file in files {
            guard LocalFiles.forEachLine(in: file, { line in
                guard let record = try? decoder.decode(ClaudeRecord.self, from: line),
                      let usage = record.message?.usage,
                      let timestamp = TimestampParser.parse(record.timestamp),
                      timestamp >= startDate
                else { return }

                let identifier = record.message?.id ?? record.uuid ?? "\(file.path):\(record.timestamp ?? "")"
                guard seenMessageIDs.insert(identifier).inserted else { return }
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
            }) else { return nil }
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
