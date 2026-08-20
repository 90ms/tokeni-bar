@testable import TokeniApplication
import Foundation
import Testing
import TokeniCore

struct ApplicationHistoryCoordinatorTests {
    @Test
    func ownsHistoryLoadingRecordingAndClearing() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UsageHistoryStore(
            fileURL: root.appending(path: "usage-history.json"),
            minimumRecordInterval: 0)
        let coordinator = UsageHistoryCoordinator(store: store)

        let initial = try await coordinator.load()
        #expect(initial.isEmpty)

        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let recorded = try await coordinator.record(
            [Self.snapshot],
            at: timestamp)
        #expect(recorded.count == 1)
        #expect(recorded[0].providerID == Self.snapshot.id)
        #expect(recorded[0].timestamp == timestamp)

        let loaded = try await coordinator.load()
        #expect(loaded == recorded)

        let cleared = try await coordinator.clear()
        #expect(cleared.isEmpty)
        let reloaded = try await coordinator.load()
        #expect(reloaded.isEmpty)
    }

    private static let snapshot = ProviderSnapshot(
        descriptor: ProviderDescriptor(
            id: .codex,
            displayName: "Codex",
            shortName: "Codex",
            systemImage: "circle",
            capabilities: .init(supportsTokenUsage: true)),
        availability: .available,
        source: .localProtocol,
        tokenUsage: TokenUsage(label: "Today", totalTokens: 12),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
}
