@testable import TokeniCore
import Foundation
import Testing

@Suite("Daily provider parsers")
struct DailyProviderParserTests {
    @Test("Codex attributes cumulative deltas after midnight")
    func codexToday() throws {
        let file = try self.fixture("codex-today", fileExtension: "jsonl")
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let aggregate = try #require(
            CodexTodayLogParser.aggregate(files: [file], since: start))

        #expect(aggregate.tokenUsage.label == "Today")
        #expect(aggregate.tokenUsage.modelID == "gpt-5.6-sol")
        #expect(aggregate.tokenUsage.inputTokens == 800)
        #expect(aggregate.tokenUsage.cachedInputTokens == 200)
        #expect(aggregate.tokenUsage.outputTokens == 240)
        #expect(aggregate.tokenUsage.reasoningTokens == 60)
        #expect(aggregate.tokenUsage.totalTokens == 1_300)
        #expect(aggregate.sessionCount == 1)
        #expect(abs((aggregate.costEstimate?.amountUSD ?? 0) - 0.0131) < 0.000_000_1)
    }

    @Test("Codex file aggregates combine to the same daily result")
    func codexFileAggregateReuse() throws {
        let file = try self.fixture("codex-today", fileExtension: "jsonl")
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let direct = try #require(
            CodexTodayLogParser.aggregate(files: [file], since: start))
        let fileAggregate = try #require(
            CodexTodayLogParser.aggregate(file: file, since: start))
        let combined = try #require(
            CodexTodayLogParser.combine([fileAggregate], since: start))

        #expect(combined.tokenUsage == direct.tokenUsage)
        #expect(combined.costEstimate == direct.costEstimate)
        #expect(combined.observedAt == direct.observedAt)
        #expect(combined.sessionCount == direct.sessionCount)
    }

    @Test("Grok Build counts complete turns once and trusts complete recorded cost")
    func grokToday() throws {
        let file = try self.fixture("grok-updates", fileExtension: "jsonl")
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let aggregate = try #require(
            GrokTodayLogParser.aggregate(files: [file], since: start))

        #expect(aggregate.tokenUsage.modelID == "grok-4")
        #expect(aggregate.tokenUsage.inputTokens == 1_100)
        #expect(aggregate.tokenUsage.cachedInputTokens == 300)
        #expect(aggregate.tokenUsage.cacheCreationInputTokens == 100)
        #expect(aggregate.tokenUsage.outputTokens == 430)
        #expect(aggregate.tokenUsage.reasoningTokens == 70)
        #expect(aggregate.tokenUsage.totalTokens == 2_000)
        #expect(aggregate.sessionCount == 1)
        #expect(abs((aggregate.costEstimate?.amountUSD ?? 0) - 0.03) < 0.000_000_1)
    }

    @Test("Copilot OTel counts chat spans and ignores tool spans")
    func copilotToday() throws {
        let file = try self.fixture("copilot-otel", fileExtension: "jsonl")
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let aggregate = try #require(
            CopilotOTelParser.aggregate(files: [file], since: start))

        #expect(aggregate.tokenUsage.modelID == "gpt-5")
        #expect(aggregate.tokenUsage.inputTokens == 1_100)
        #expect(aggregate.tokenUsage.cachedInputTokens == 300)
        #expect(aggregate.tokenUsage.cacheCreationInputTokens == 100)
        #expect(aggregate.tokenUsage.outputTokens == 500)
        #expect(aggregate.tokenUsage.reasoningTokens == 70)
        #expect(aggregate.tokenUsage.totalTokens == 2_070)
    }

    @Test("Copilot completed-session fallback uses the last same-day rollup")
    func copilotCompletedSessionFallback() throws {
        let file = try self.fixture(
            "copilot-session-events",
            fileExtension: "jsonl")
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let aggregate = try #require(
            CopilotSessionStateParser.aggregate(files: [file], since: start))

        #expect(aggregate.tokenUsage.modelID == "gpt-5")
        #expect(aggregate.tokenUsage.inputTokens == 1_100)
        #expect(aggregate.tokenUsage.cachedInputTokens == 300)
        #expect(aggregate.tokenUsage.cacheCreationInputTokens == 100)
        #expect(aggregate.tokenUsage.outputTokens == 150)
        #expect(aggregate.tokenUsage.reasoningTokens == 30)
        #expect(aggregate.tokenUsage.totalTokens == 1_680)
    }

    @Test("Cline aggregates timestamped API usage and recorded cost")
    func clineToday() throws {
        let file = try self.fixture("cline-ui-messages", fileExtension: "json")
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let aggregate = try #require(
            ClineLogParser.aggregate(files: [file], since: start))

        #expect(aggregate.tokenUsage.inputTokens == 1_100)
        #expect(aggregate.tokenUsage.cachedInputTokens == 300)
        #expect(aggregate.tokenUsage.cacheCreationInputTokens == 100)
        #expect(aggregate.tokenUsage.outputTokens == 500)
        #expect(aggregate.tokenUsage.totalTokens == 2_000)
        #expect(aggregate.taskCount == 1)
        #expect(abs((aggregate.costEstimate?.amountUSD ?? 0) - 0.03) < 0.000_000_1)
    }

    @Test("Antigravity decodes timestamped SQLite metadata records")
    func antigravityToday() throws {
        let file = try self.fixture("antigravity-metadata", fileExtension: "json")
        let rows = try JSONDecoder().decode(
            [AntigravityMetadataRow].self,
            from: Data(contentsOf: file))
        let start = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let aggregate = try #require(AntigravityMetadataParser.aggregate(
            [AntigravityDatabaseRows(sessionID: "conversation-1", rows: rows)],
            since: start))

        #expect(aggregate.tokenUsage.modelID == "gemini-3.5-flash")
        #expect(aggregate.tokenUsage.inputTokens == 1_000)
        #expect(aggregate.tokenUsage.outputTokens == 250)
        #expect(aggregate.tokenUsage.reasoningTokens == 50)
        #expect(aggregate.tokenUsage.totalTokens == 1_300)
        #expect(aggregate.sessionCount == 1)
    }

    private func fixture(_ name: String, fileExtension: String) throws -> URL {
        try #require(Bundle.module.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Fixtures"))
    }
}
