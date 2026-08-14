import Foundation
import Testing
@testable import TokeniCore

@Suite("Growth usage observations")
struct GrowthUsageObservationTests {
    @Test("Measurement keys are stable and contain no absolute path")
    func stableMeasurementKey() {
        let observation = GrowthUsageObservation(
            providerID: .gemini,
            scope: .session,
            scopeID: "session-sanitized",
            totalTokens: 2_810,
            observedAt: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(observation.measurementKey == "gemini:session:session-sanitized")
        #expect(!observation.measurementKey.contains("/"))
    }

    @Test("Grok uses complete local turns as today's growth observation")
    func grokDailyTotal() async throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let directory = home.appending(
            path: ".grok/sessions/session-sanitized",
            directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = UInt64(Date.now.timeIntervalSince1970)
        try Data(
            """
            {"timestamp":\(timestamp),"method":"_x.ai/session/update","params":{"sessionId":"session-sanitized","update":{"sessionUpdate":"turn_completed","prompt_id":"prompt-1","usage":{"inputTokens":1200,"outputTokens":300,"totalTokens":1500,"modelUsage":{"grok-test":{}}}}}}
            """.utf8)
            .write(to: directory.appending(path: "updates.jsonl"))

        let snapshot = await GrokUsageProvider(homeDirectory: home).fetchUsage()

        #expect(snapshot.tokenUsage?.totalTokens == 1_500)
        #expect(snapshot.growthUsageObservation?.scope == .daily)
        #expect(snapshot.growthUsageObservation?.scopeID == GrowthLocalDate.key(for: .now))
        #expect(snapshot.growthUsageObservation?.totalTokens == 1_500)
    }
}
