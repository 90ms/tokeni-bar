import Foundation

public enum CompanionEconomyTransactionKind: Codable, Hashable, Sendable {
    case purchaseEgg(
        definitionID: CompanionEggDefinitionID,
        seed: UInt64,
        price: Int)
    case sellEgg(eggID: UUID, value: Int)
    case sellPet(generationID: UUID, value: Int)
}

public struct CompanionEconomyTransaction:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    public let id: UUID
    public let kind: CompanionEconomyTransactionKind
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: CompanionEconomyTransactionKind,
        createdAt: Date = .now)
    {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
    }
}

public struct CompanionEconomyTransactionJournal:
    Codable,
    Hashable,
    Sendable
{
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var pending: [CompanionEconomyTransaction]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        pending: [CompanionEconomyTransaction] = [])
    {
        self.schemaVersion = schemaVersion
        self.pending = pending
    }

    public func isValid() -> Bool {
        self.schemaVersion == Self.currentSchemaVersion
            && Set(self.pending.map(\.id)).count == self.pending.count
            && self.pending.allSatisfy { transaction in
                switch transaction.kind {
                case let .purchaseEgg(_, _, price):
                    price >= 0
                case let .sellEgg(_, value), let .sellPet(_, value):
                    value >= 0
                }
            }
    }
}

public actor CompanionEconomyTransactionStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-economy-transactions.json")
    }

    public func load() throws -> CompanionEconomyTransactionJournal {
        let fileExisted = FileManager.default.fileExists(
            atPath: self.fileURL.path)
        let quarantineExisted = RecoverableFileStorage.hasQuarantinedFile(
            for: self.fileURL)
        if let journal = try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: Self.decode)
        {
            return journal
        }
        guard !fileExisted, !quarantineExisted else {
            throw CompanionEconomyTransactionStoreError.unrecoverableJournal
        }
        return CompanionEconomyTransactionJournal()
    }

    public func begin(_ transaction: CompanionEconomyTransaction) throws {
        var journal = try self.load()
        guard !journal.pending.contains(where: { $0.id == transaction.id })
        else { return }
        journal.pending.append(transaction)
        try self.save(journal)
    }

    public func complete(_ transactionID: UUID) throws {
        var journal = try self.load()
        journal.pending.removeAll { $0.id == transactionID }
        try self.save(journal)
    }

    private static func decode(
        _ data: Data) throws -> CompanionEconomyTransactionJournal
    {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let journal = try decoder.decode(
            CompanionEconomyTransactionJournal.self,
            from: data)
        guard journal.isValid() else {
            throw CompanionEconomyTransactionStoreError.invalidJournal
        }
        return journal
    }

    private func save(_ journal: CompanionEconomyTransactionJournal) throws {
        guard journal.isValid() else {
            throw CompanionEconomyTransactionStoreError.invalidJournal
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try RecoverableFileStorage.write(
            encoder.encode(journal),
            to: self.fileURL)
    }
}

private enum CompanionEconomyTransactionStoreError: Error {
    case invalidJournal
    case unrecoverableJournal
}
