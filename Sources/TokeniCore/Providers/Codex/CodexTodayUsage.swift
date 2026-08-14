import Foundation

struct CodexTodayUsage {
    let tokenUsage: TokenUsage
    let costEstimate: TokenCostEstimate?
    let observedAt: Date
    let sessionCount: Int
}

enum CodexTodayLogParser {
    static func aggregate(
        files: [URL],
        since startDate: Date) -> CodexTodayUsage?
    {
        var input: Int64 = 0
        var cached: Int64 = 0
        var output: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0
        var observedAt = startDate
        var sessionCount = 0
        var modelIDs: Set<String> = []
        var amountUSD = 0.0
        var allDeltasPriced = true
        var deltaCount = 0

        for file in files {
            guard let session = self.aggregate(file: file, since: startDate) else { continue }
            sessionCount += 1
            observedAt = max(observedAt, session.observedAt)
            input = saturatedAdd(input, session.inputTokens)
            cached = saturatedAdd(cached, session.cachedInputTokens)
            output = saturatedAdd(output, session.outputTokens)
            reasoning = saturatedAdd(reasoning, session.reasoningTokens)
            total = saturatedAdd(total, session.totalTokens)
            modelIDs.formUnion(session.modelIDs)
            amountUSD += session.amountUSD
            deltaCount += session.deltaCount
            allDeltasPriced = allDeltasPriced && session.allDeltasPriced
        }

        guard sessionCount > 0 else { return nil }
        let usage = TokenUsage(
            label: "Today",
            modelID: modelIDs.count == 1 ? modelIDs.first : nil,
            inputTokens: input,
            cachedInputTokens: cached,
            outputTokens: output,
            reasoningTokens: reasoning,
            totalTokens: total)
        let cost = deltaCount > 0 && allDeltasPriced
            ? TokenCostEstimate(
                label: "Today",
                amountUSD: amountUSD,
                modelIDs: modelIDs.sorted())
            : nil
        return CodexTodayUsage(
            tokenUsage: usage,
            costEstimate: cost,
            observedAt: observedAt,
            sessionCount: sessionCount)
    }

    private static func aggregate(
        file: URL,
        since startDate: Date) -> SessionAggregate?
    {
        let decoder = JSONDecoder()
        var currentModelID: String?
        var previousUsage: TokenBreakdown?
        var sawEventBeforeStart = false
        var sawTokenEventToday = false
        var observedAt = startDate
        var input: Int64 = 0
        var cached: Int64 = 0
        var output: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0
        var modelIDs: Set<String> = []
        var amountUSD = 0.0
        var allDeltasPriced = true
        var deltaCount = 0

        guard LocalFiles.forEachLine(in: file, { line in
            guard let event = try? decoder.decode(Event.self, from: line),
                  let timestamp = TimestampParser.parse(event.timestamp)
            else { return }

            if timestamp < startDate {
                sawEventBeforeStart = true
            }
            if let model = event.payload?.model?.trimmingCharacters(in: .whitespacesAndNewlines),
               !model.isEmpty
            {
                currentModelID = model
            }
            guard event.type == "event_msg",
                  event.payload?.type == "token_count",
                  let current = event.payload?.info?.totalTokenUsage
            else { return }

            defer { previousUsage = current }
            guard timestamp >= startDate else { return }
            sawTokenEventToday = true
            observedAt = max(observedAt, timestamp)

            let delta: TokenBreakdown
            if let previousUsage {
                guard current.isAtLeast(previousUsage) else { return }
                delta = current.subtracting(previousUsage)
            } else if !sawEventBeforeStart {
                delta = current
            } else {
                // A session existed before today but has no trustworthy token
                // baseline. Establish one instead of assigning old usage today.
                return
            }
            guard delta.totalTokens > 0 else { return }

            let uncachedInput = max(delta.inputTokens - delta.cachedInputTokens, 0)
            let responseOutput = max(
                delta.outputTokens - delta.reasoningOutputTokens,
                0)
            input = saturatedAdd(input, uncachedInput)
            cached = saturatedAdd(cached, delta.cachedInputTokens)
            output = saturatedAdd(output, responseOutput)
            reasoning = saturatedAdd(reasoning, delta.reasoningOutputTokens)
            total = saturatedAdd(total, delta.totalTokens)
            deltaCount += 1

            guard let modelID = currentModelID else {
                allDeltasPriced = false
                return
            }
            modelIDs.insert(modelID)
            let usage = TokenUsage(
                label: "Today",
                modelID: modelID,
                inputTokens: uncachedInput,
                cachedInputTokens: delta.cachedInputTokens,
                outputTokens: responseOutput,
                reasoningTokens: delta.reasoningOutputTokens,
                totalTokens: delta.totalTokens)
            guard let estimate = TokenPricingCatalog.estimate(
                providerID: .codex,
                usage: usage,
                at: timestamp)
            else {
                allDeltasPriced = false
                return
            }
            amountUSD += estimate.amountUSD
        }) else { return nil }

        guard sawTokenEventToday, deltaCount > 0 else { return nil }
        return SessionAggregate(
            observedAt: observedAt,
            inputTokens: input,
            cachedInputTokens: cached,
            outputTokens: output,
            reasoningTokens: reasoning,
            totalTokens: total,
            modelIDs: modelIDs,
            amountUSD: amountUSD,
            allDeltasPriced: allDeltasPriced,
            deltaCount: deltaCount)
    }

    private static func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(max(rhs, 0))
        return result.overflow ? .max : result.partialValue
    }

    private struct SessionAggregate {
        let observedAt: Date
        let inputTokens: Int64
        let cachedInputTokens: Int64
        let outputTokens: Int64
        let reasoningTokens: Int64
        let totalTokens: Int64
        let modelIDs: Set<String>
        let amountUSD: Double
        let allDeltasPriced: Bool
        let deltaCount: Int
    }

    private struct Event: Decodable {
        let timestamp: String?
        let type: String
        let payload: Payload?

        struct Payload: Decodable {
            let type: String?
            let model: String?
            let info: Info?
        }

        struct Info: Decodable {
            let totalTokenUsage: TokenBreakdown?

            enum CodingKeys: String, CodingKey {
                case totalTokenUsage = "total_token_usage"
            }
        }
    }

    private struct TokenBreakdown: Decodable {
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

        func isAtLeast(_ other: Self) -> Bool {
            self.inputTokens >= other.inputTokens
                && self.cachedInputTokens >= other.cachedInputTokens
                && self.outputTokens >= other.outputTokens
                && self.reasoningOutputTokens >= other.reasoningOutputTokens
                && self.totalTokens >= other.totalTokens
        }

        func subtracting(_ other: Self) -> Self {
            Self(
                inputTokens: self.inputTokens - other.inputTokens,
                cachedInputTokens: self.cachedInputTokens - other.cachedInputTokens,
                outputTokens: self.outputTokens - other.outputTokens,
                reasoningOutputTokens: self.reasoningOutputTokens - other.reasoningOutputTokens,
                totalTokens: self.totalTokens - other.totalTokens)
        }

        init(
            inputTokens: Int64,
            cachedInputTokens: Int64,
            outputTokens: Int64,
            reasoningOutputTokens: Int64,
            totalTokens: Int64)
        {
            self.inputTokens = inputTokens
            self.cachedInputTokens = cachedInputTokens
            self.outputTokens = outputTokens
            self.reasoningOutputTokens = reasoningOutputTokens
            self.totalTokens = totalTokens
        }
    }
}
