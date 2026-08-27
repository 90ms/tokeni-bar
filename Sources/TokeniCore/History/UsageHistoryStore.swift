import Foundation

public struct UsageHistoryRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let providerID: ProviderID
    public let providerName: String
    public let windows: [WindowSample]
    public let tokenTotal: Int64?
    public let costUSD: Double?

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        providerID: ProviderID,
        providerName: String,
        windows: [WindowSample],
        tokenTotal: Int64?,
        costUSD: Double? = nil)
    {
        self.id = id
        self.timestamp = timestamp
        self.providerID = providerID
        self.providerName = providerName
        self.windows = windows
        self.tokenTotal = tokenTotal
        self.costUSD = costUSD
    }

    public struct WindowSample: Identifiable, Codable, Hashable, Sendable {
        public let id: String
        public let label: String
        public let remainingPercent: Double

        public init(id: String, label: String, remainingPercent: Double) {
            self.id = id
            self.label = label
            self.remainingPercent = remainingPercent
        }
    }
}

public actor UsageHistoryStore {
    private let fileURL: URL
    private let retentionInterval: TimeInterval
    private let minimumRecordInterval: TimeInterval
    private let maximumRecordCount: Int
    private var cachedRecords: [UsageHistoryRecord]?
    private var lastTimestampByProvider: [ProviderID: Date]?

    public init(
        fileURL: URL? = nil,
        retentionDays: Int = 30,
        minimumRecordInterval: TimeInterval = 15 * 60,
        maximumRecordCount: Int = 50_000)
    {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "usage-history.json")
        self.retentionInterval = TimeInterval(retentionDays * 24 * 60 * 60)
        self.minimumRecordInterval = minimumRecordInterval
        self.maximumRecordCount = max(maximumRecordCount, 0)
    }

    public func records() throws -> [UsageHistoryRecord] {
        if let cachedRecords { return cachedRecords }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: {
                try decoder.decode([UsageHistoryRecord].self, from: $0)
            }) ?? []
        self.cachedRecords = records
        self.lastTimestampByProvider = Self.lastTimestamps(in: records)
        return records
    }

    public func record(_ snapshots: [ProviderSnapshot], at timestamp: Date = .now) throws {
        var records = try self.records()
        let cutoff = timestamp.addingTimeInterval(-self.retentionInterval)
        let originalCount = records.count
        records.removeAll { $0.timestamp < cutoff }
        var didChange = records.count != originalCount
        let requiresSorting = records.last.map { timestamp < $0.timestamp } ?? false

        var lastTimestamps = self.lastTimestampByProvider
            ?? Self.lastTimestamps(in: records)
        for snapshot in snapshots where snapshot.availability == .available {
            guard !snapshot.quotaWindows.isEmpty || snapshot.tokenUsage != nil else { continue }
            let lastTimestamp = lastTimestamps[snapshot.id]
            guard lastTimestamp.map({ timestamp.timeIntervalSince($0) >= self.minimumRecordInterval }) != false
            else { continue }

            records.append(UsageHistoryRecord(
                timestamp: timestamp,
                providerID: snapshot.id,
                providerName: snapshot.descriptor.displayName,
                windows: snapshot.quotaWindows.map {
                    UsageHistoryRecord.WindowSample(
                        id: $0.id,
                        label: $0.label,
                        remainingPercent: $0.remainingPercent)
                },
                tokenTotal: snapshot.tokenUsage?.totalTokens,
                costUSD: snapshot.costEstimate?.amountUSD))
            lastTimestamps[snapshot.id] = timestamp
            didChange = true
        }

        guard didChange else { return }

        if requiresSorting {
            records.sort { $0.timestamp < $1.timestamp }
        }
        if records.count > self.maximumRecordCount {
            records.removeFirst(records.count - self.maximumRecordCount)
        }
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try RecoverableFileStorage.write(
            encoder.encode(records),
            to: self.fileURL)
        self.cachedRecords = records
        self.lastTimestampByProvider = Self.lastTimestamps(in: records)
    }

    public func clear() throws {
        try RecoverableFileStorage.removePrimaryAndBackups(for: self.fileURL)
        self.cachedRecords = []
        self.lastTimestampByProvider = [:]
    }

    private static func lastTimestamps(
        in records: [UsageHistoryRecord]) -> [ProviderID: Date]
    {
        var result: [ProviderID: Date] = [:]
        for record in records {
            if result[record.providerID].map({ record.timestamp > $0 }) != false {
                result[record.providerID] = record.timestamp
            }
        }
        return result
    }
}
