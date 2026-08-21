import Foundation
import TokeniCore

public protocol UsageHistoryCoordinating: Sendable {
    func load() async throws -> [UsageHistoryRecord]
    func record(
        _ snapshots: [ProviderSnapshot],
        at timestamp: Date) async throws -> [UsageHistoryRecord]
    func clear() async throws -> [UsageHistoryRecord]
}

public actor UsageHistoryCoordinator: UsageHistoryCoordinating {
    private let store: UsageHistoryStore
    private var cachedRecords: [UsageHistoryRecord] = []

    public init(store: UsageHistoryStore = UsageHistoryStore()) {
        self.store = store
    }

    public func load() async throws -> [UsageHistoryRecord] {
        let records = try await self.store.records()
        self.cachedRecords = records
        return records
    }

    public func record(
        _ snapshots: [ProviderSnapshot],
        at timestamp: Date = .now) async throws -> [UsageHistoryRecord]
    {
        try await self.store.record(snapshots, at: timestamp)
        return try await self.load()
    }

    public func clear() async throws -> [UsageHistoryRecord] {
        try await self.store.clear()
        self.cachedRecords = []
        return self.cachedRecords
    }
}
