@testable import TokeniCore
import Foundation
import Testing

struct ProviderActivityTests {
    @Test
    func evaluatorUsesTheConfiguredGraceWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(ProviderActivityEvaluator.snapshot(
            providerID: .codex,
            lastActivityAt: now.addingTimeInterval(-15),
            now: now,
            activeWindow: 15).state == .active)
        #expect(ProviderActivityEvaluator.snapshot(
            providerID: .codex,
            lastActivityAt: now.addingTimeInterval(-15.1),
            now: now,
            activeWindow: 15).state == .idle)
        #expect(ProviderActivityEvaluator.snapshot(
            providerID: .codex,
            lastActivityAt: nil,
            now: now,
            activeWindow: 15).state == .idle)
        #expect(ProviderActivityEvaluator.snapshot(
            providerID: .codex,
            lastActivityAt: now.addingTimeInterval(2),
            now: now,
            activeWindow: 15).state == .idle)
    }

    @Test
    func providersDetectOnlyTheirUsageFileModificationTimes() throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let now = Date.now
        let modifiedAt = now.addingTimeInterval(-2)
        let files = [
            ".codex/sessions/2026/session.jsonl",
            ".claude/projects/project/session.jsonl",
            ".copilot/otel/usage.jsonl",
            "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks/task/ui_messages.json",
            ".gemini/antigravity-cli/conversations/conversation.db",
            ".grok/sessions/current/updates.jsonl",
        ]
        for path in files {
            let file = home.appending(path: path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try Data().write(to: file)
            try FileManager.default.setAttributes(
                [.modificationDate: modifiedAt],
                ofItemAtPath: file.path)
        }

        let providers: [any UsageActivityProviding] = [
            CodexUsageProvider(homeDirectory: home),
            ClaudeUsageProvider(homeDirectory: home),
            CopilotUsageProvider(homeDirectory: home),
            ClineUsageProvider(homeDirectory: home),
            AntigravityUsageProvider(homeDirectory: home),
            GrokUsageProvider(homeDirectory: home),
        ]
        let cutoff = now.addingTimeInterval(-15)

        for provider in providers {
            let detected = try #require(provider.latestActivityDate(since: cutoff))
            #expect(abs(detected.timeIntervalSince(modifiedAt)) < 0.1)
        }
    }

    @Test
    func defaultProvidersExposeActivityDetection() {
        let providers = ProviderRegistry.defaultProviders()
        #expect(providers.allSatisfy { $0 is any UsageActivityProviding })
    }
}
