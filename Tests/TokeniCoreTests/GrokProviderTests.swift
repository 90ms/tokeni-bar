@testable import TokeniCore
import Foundation
import Testing

struct GrokProviderTests {
    @Test
    func providerReadsFilesBelowInjectedSessionsDirectory() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sessionDirectory = temporaryRoot.appending(
            path: "session-sanitized",
            directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let fixture = try #require(Bundle.module.url(
            forResource: "grok-updates",
            withExtension: "jsonl",
            subdirectory: "Fixtures"))
        try FileManager.default.copyItem(
            at: fixture,
            to: sessionDirectory.appending(path: "updates.jsonl"))

        let activityDate = GrokUsageProvider(sessionsDirectory: temporaryRoot)
            .latestActivityDate(since: .distantPast)

        #expect(activityDate != nil)
    }
}
