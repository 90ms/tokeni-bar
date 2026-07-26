import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion state storage")
struct CompanionStateStoreTests {
    @Test("Round trips only companion progress")
    func roundTripsState() async throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "companion-state.json")
        defer { try? fileManager.removeItem(at: directory) }

        let timestamp = try #require(
            ISO8601DateFormatter().date(from: "2026-07-26T10:00:00Z"))
        let expected = CompanionState(
            totalXP: 42,
            dailyXP: 12,
            dailyXPDate: "2026-07-26",
            lastAwardedMinute: timestamp,
            lastActiveAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp)
        let store = CompanionStateStore(fileURL: fileURL)

        try await store.save(expected)
        let loaded = try await store.load()
        let contents = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(loaded == expected)
        #expect(!contents.contains("token"))
        #expect(!contents.contains("provider"))
        #expect(!contents.contains("prompt"))
    }
}
