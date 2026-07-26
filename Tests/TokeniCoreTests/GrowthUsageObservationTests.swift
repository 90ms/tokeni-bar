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

    @Test("Grok combines compacted and current session tokens for growth")
    func grokCompactionTotal() async throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let directory = home.appending(
            path: ".grok/sessions/session-sanitized",
            directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(
            """
            {
              "contextTokensUsed": 1200,
              "contextWindowTokens": 10000,
              "totalTokensBeforeCompaction": 3400,
              "primaryModelId": "grok-test"
            }
            """.utf8)
            .write(to: directory.appending(path: "signals.json"))

        let snapshot = await GrokUsageProvider(homeDirectory: home).fetchUsage()

        #expect(snapshot.tokenUsage?.totalTokens == 1_200)
        #expect(snapshot.growthUsageObservation?.scope == .session)
        #expect(snapshot.growthUsageObservation?.scopeID == "session-sanitized")
        #expect(snapshot.growthUsageObservation?.totalTokens == 4_600)
    }
}
