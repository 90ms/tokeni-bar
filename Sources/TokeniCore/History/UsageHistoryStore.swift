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
    private var cachedRecords: [UsageHistoryRecord]?

    public init(
        fileURL: URL? = nil,
        retentionDays: Int = 30,
        minimumRecordInterval: TimeInterval = 15 * 60)
    {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "usage-history.json")
        self.retentionInterval = TimeInterval(retentionDays * 24 * 60 * 60)
        self.minimumRecordInterval = minimumRecordInterval
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
        return records
    }

    public func record(_ snapshots: [ProviderSnapshot], at timestamp: Date = .now) throws {
        var records = try self.records()
        let cutoff = timestamp.addingTimeInterval(-self.retentionInterval)
        records.removeAll { $0.timestamp < cutoff }

        for snapshot in snapshots where snapshot.availability == .available {
            guard !snapshot.quotaWindows.isEmpty || snapshot.tokenUsage != nil else { continue }
            let lastTimestamp = records.last(where: { $0.providerID == snapshot.id })?.timestamp
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
        }

        records.sort { $0.timestamp < $1.timestamp }
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
    }

    public func clear() throws {
        try RecoverableFileStorage.removePrimaryAndBackups(for: self.fileURL)
        self.cachedRecords = []
    }
}
