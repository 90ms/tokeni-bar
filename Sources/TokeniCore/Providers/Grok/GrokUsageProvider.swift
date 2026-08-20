import Foundation

public struct GrokUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .grok,
        displayName: "Grok Build",
        shortName: "Grok",
        systemImage: "xmark",
        iconAssetName: "grok",
        capabilities: .init(
            supportsQuotaWindows: true,
            supportsTokenUsage: true))

    private let sessionsDirectory: URL
    private let calendar: Calendar

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current)
    {
        self.init(
            sessionsDirectory: homeDirectory.appending(
                path: ".grok/sessions",
                directoryHint: .isDirectory),
            calendar: calendar)
    }

    public init(sessionsDirectory: URL, calendar: Calendar = .current) {
        self.sessionsDirectory = sessionsDirectory
        self.calendar = calendar
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let updateFiles = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            named: "updates.jsonl",
            modifiedAfter: startOfDay,
            limit: 256)
        let todayUsage = GrokTodayLogParser.aggregate(
            files: updateFiles,
            since: startOfDay)
        let signals = self.latestSignals()

        guard todayUsage != nil || signals != nil else {
            return .init(
                descriptor: self.descriptor,
                availability: .unavailable,
                source: .localSessionLog,
                detail: "No Grok Build session usage was found")
        }

        let contextWindow = signals.map { signals in
            let contextUsed = max(signals.value.contextTokensUsed ?? 0, 0)
            let contextPercent = signals.value.contextWindowUsage ?? {
                guard let window = signals.value.contextWindowTokens, window > 0 else { return 0 }
                return Double(contextUsed) / Double(window) * 100
            }()
            return QuotaWindow(
                id: "context",
                kind: .context,
                label: "Context",
                usedPercent: contextPercent)
        }
        let observedAt = max(
            todayUsage?.observedAt ?? .distantPast,
            signals?.modifiedAt ?? .distantPast)
        let detail: String
        if let todayUsage {
            detail = "Today across \(todayUsage.sessionCount) local Grok Build sessions"
        } else {
            detail = "Grok Build found, but no completed token record was written today"
        }

        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            quotaWindows: contextWindow.map { [$0] } ?? [],
            tokenUsage: todayUsage?.tokenUsage,
            costEstimate: todayUsage?.costEstimate,
            growthUsageObservation: todayUsage.map {
                GrowthUsageObservation.daily(
                    providerID: .grok,
                    dateKey: GrowthLocalDate.key(for: $0.observedAt, calendar: self.calendar),
                    totalTokens: $0.tokenUsage.totalTokens,
                    observedAt: $0.observedAt)
            },
            detail: detail,
            updatedAt: observedAt == .distantPast ? .now : observedAt)
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.sessionsDirectory,
            modifiedAfter: cutoff,
            matching: {
                $0.lastPathComponent == "updates.jsonl"
                    || $0.lastPathComponent == "signals.json"
            })
    }

    private func latestSignals() -> (value: GrokSignals, modifiedAt: Date)? {
        guard let file = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            named: "signals.json",
            limit: 1).first,
            let data = LocalFiles.data(in: file),
            let signals = try? JSONDecoder().decode(GrokSignals.self, from: data)
        else { return nil }
        let modifiedAt = (try? file.resourceValues(
            forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now
        return (signals, modifiedAt)
    }
}

struct GrokTodayUsage {
    let tokenUsage: TokenUsage
    let costEstimate: TokenCostEstimate?
    let observedAt: Date
    let sessionCount: Int
}

enum GrokTodayLogParser {
    static func aggregate(files: [URL], since startDate: Date) -> GrokTodayUsage? {
        guard LocalFiles.totalSize(of: files) != nil else { return nil }
        let decoder = JSONDecoder()
        var seenTurns: Set<String> = []
        var sessionIDs: Set<String> = []
        var modelIDs: Set<String> = []
        var input: Int64 = 0
        var cached: Int64 = 0
        var cacheCreation: Int64 = 0
        var output: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0
        var costTicks: Int64 = 0
        var allCostsComplete = true
        var usageCount = 0
        var observedAt = startDate

        for file in files {
            guard LocalFiles.forEachLine(in: file, { line in
                guard let envelope = try? decoder.decode(GrokUpdateEnvelope.self, from: line),
                      envelope.method == "_x.ai/session/update",
                      let update = envelope.params.update,
                      update.sessionUpdate == "turn_completed",
                      let promptID = update.promptID,
                      let usage = update.usage,
                      usage.usageIsIncomplete != true,
                      let timestamp = envelope.date,
                      timestamp >= startDate
                else { return }

                let sessionID = envelope.params.sessionID
                    ?? file.deletingLastPathComponent().lastPathComponent
                guard seenTurns.insert("\(sessionID):\(promptID)").inserted else { return }

                let fullInput = max(usage.inputTokens ?? 0, 0)
                let cacheRead = max(usage.cachedReadTokens ?? 0, 0)
                let cacheWrite = max(usage.cacheCreationTokens ?? 0, 0)
                let uncachedInput = max(fullInput - cacheRead - cacheWrite, 0)
                let fullOutput = max(usage.outputTokens ?? 0, 0)
                let reasoningOutput = min(max(usage.reasoningTokens ?? 0, 0), fullOutput)
                let responseOutput = fullOutput - reasoningOutput
                let reportedTotal = max(usage.totalTokens ?? 0, 0)
                let normalizedTotal = reportedTotal > 0
                    ? reportedTotal
                    : saturatedAdd(fullInput, fullOutput)
                guard normalizedTotal > 0 else { return }

                input = saturatedAdd(input, uncachedInput)
                cached = saturatedAdd(cached, cacheRead)
                cacheCreation = saturatedAdd(cacheCreation, cacheWrite)
                output = saturatedAdd(output, responseOutput)
                reasoning = saturatedAdd(reasoning, reasoningOutput)
                total = saturatedAdd(total, normalizedTotal)
                observedAt = max(observedAt, timestamp)
                usageCount += 1
                sessionIDs.insert(sessionID)
                if let modelUsage = usage.modelUsage {
                    modelIDs.formUnion(modelUsage.keys)
                }

                if usage.costIsPartial == true {
                    allCostsComplete = false
                } else if let ticks = usage.costUSDTicks, ticks >= 0 {
                    costTicks = saturatedAdd(costTicks, ticks)
                } else {
                    allCostsComplete = false
                }
            }) else { continue }
        }

        guard usageCount > 0 else { return nil }
        let tokenUsage = TokenUsage(
            label: "Today",
            modelID: modelIDs.count == 1 ? modelIDs.first : nil,
            inputTokens: input,
            cacheCreationInputTokens: cacheCreation,
            cachedInputTokens: cached,
            outputTokens: output,
            reasoningTokens: reasoning,
            totalTokens: total)
        let costEstimate = allCostsComplete
            ? TokenCostEstimate(
                label: "Today · provider recorded",
                amountUSD: Double(costTicks) / 10_000_000_000,
                modelIDs: modelIDs.sorted())
            : nil
        return GrokTodayUsage(
            tokenUsage: tokenUsage,
            costEstimate: costEstimate,
            observedAt: observedAt,
            sessionCount: sessionIDs.count)
    }

    private static func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(max(rhs, 0))
        return result.overflow ? .max : result.partialValue
    }
}

private struct GrokUpdateEnvelope: Decodable {
    let timestamp: UInt64?
    let method: String
    let params: Params

    var date: Date? {
        self.timestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    struct Params: Decodable {
        let sessionID: String?
        let update: Update?

        enum CodingKeys: String, CodingKey {
            case sessionID = "sessionId"
            case update
        }
    }

    struct Update: Decodable {
        let sessionUpdate: String?
        let promptID: String?
        let usage: GrokPromptUsage?

        enum CodingKeys: String, CodingKey {
            case sessionUpdate
            case promptID = "prompt_id"
            case usage
        }
    }
}

private struct GrokPromptUsage: Decodable {
    let inputTokens: Int64?
    let outputTokens: Int64?
    let totalTokens: Int64?
    let cachedReadTokens: Int64?
    let cacheCreationTokens: Int64?
    let reasoningTokens: Int64?
    let costUSDTicks: Int64?
    let costIsPartial: Bool?
    let usageIsIncomplete: Bool?
    let modelUsage: [String: GrokUsageModel]?

    enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens, totalTokens
        case cachedReadTokens, cacheCreationTokens, reasoningTokens
        case costUSDTicks = "costUsdTicks"
        case costIsPartial, usageIsIncomplete, modelUsage
    }
}

private struct GrokUsageModel: Decodable {}

private struct GrokSignals: Decodable {
    let contextTokensUsed: Int64?
    let contextWindowTokens: Int64?
    let contextWindowUsage: Double?
}
