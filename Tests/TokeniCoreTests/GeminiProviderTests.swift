@testable import TokeniCore
import Foundation
import Testing

struct GeminiProviderTests {
    @Test
    func aggregatesPerRequestUsageForTheLatestSessionWithoutConversationContent() throws {
        let file = try #require(Bundle.module.url(
            forResource: "gemini-session",
            withExtension: "json",
            subdirectory: "Fixtures"))
        let parsed = try #require(GeminiSessionParser.latestUsage(in: file))
        let usage = parsed.tokenUsage

        #expect(usage.label == "Latest session")
        #expect(usage.modelID == "gemini-test-model")
        #expect(usage.inputTokens == 1800)
        #expect(usage.cachedInputTokens == 600)
        #expect(usage.outputTokens == 250)
        #expect(usage.reasoningTokens == 140)
        #expect(usage.totalTokens == 2810)
        #expect(parsed.timestamp == Date(timeIntervalSince1970: 1_784_246_520))
    }

    @Test
    func providerReadsOnlySessionFilesBelowInjectedTemporaryDirectory() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let providerRoot = temporaryHome.appending(
            path: "gemini-data",
            directoryHint: .isDirectory)
        let chats = providerRoot.appending(
            path: "project/chats",
            directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: chats, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        let fixture = try #require(Bundle.module.url(
            forResource: "gemini-session",
            withExtension: "json",
            subdirectory: "Fixtures"))
        try FileManager.default.copyItem(
            at: fixture,
            to: chats.appending(path: "session-sanitized.json"))

        let snapshot = await GeminiUsageProvider(temporaryDirectory: providerRoot).fetchUsage()

        #expect(snapshot.availability == .available)
        #expect(snapshot.source == .localSessionLog)
        #expect(snapshot.tokenUsage?.totalTokens == 2810)
        #expect(snapshot.growthUsageObservation?.scope == .session)
        #expect(snapshot.growthUsageObservation?.scopeID == "session-sanitized")
        #expect(snapshot.growthUsageObservation?.totalTokens == 2810)
        #expect(snapshot.quotaWindows.isEmpty)
        #expect(snapshot.costEstimate == nil)
    }
}
