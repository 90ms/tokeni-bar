import Foundation

/// A small JSON-backed implementation of the shared settings contract.
///
/// The file is intentionally limited to the value types exposed by
/// `SettingsStoring`. Missing or invalid files are treated as an empty store,
/// which lets callers use their existing defaults without guessing a value.
public final class JSONFileSettingsStore: SettingsStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private var values: [String: JSONSettingsValue]

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.values = Self.loadValues(from: fileURL)
    }

    public func containsValue(forKey key: String) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.values[key] != nil
    }

    public func bool(forKey key: String) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard case let .bool(value) = self.values[key] else { return false }
        return value
    }

    public func integer(forKey key: String) -> Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard case let .integer(value) = self.values[key] else { return 0 }
        return value
    }

    public func double(forKey key: String) -> Double {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard case let .double(value) = self.values[key] else { return 0 }
        return value
    }

    public func string(forKey key: String) -> String? {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard case let .string(value) = self.values[key] else { return nil }
        return value
    }

    public func stringArray(forKey key: String) -> [String]? {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard case let .stringArray(value) = self.values[key] else { return nil }
        return value
    }

    public func date(forKey key: String) -> Date? {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard case let .date(value) = self.values[key] else { return nil }
        return value
    }

    public func set(_ value: Bool, forKey key: String) {
        self.update(.bool(value), forKey: key)
    }

    public func set(_ value: Int, forKey key: String) {
        self.update(.integer(value), forKey: key)
    }

    public func set(_ value: Double, forKey key: String) {
        self.update(.double(value), forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        self.update(.string(value), forKey: key)
    }

    public func set(_ value: [String], forKey key: String) {
        self.update(.stringArray(value), forKey: key)
    }

    public func set(_ value: Date, forKey key: String) {
        self.update(.date(value), forKey: key)
    }

    public func removeValue(forKey key: String) {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard self.values[key] != nil else { return }

        var nextValues = self.values
        nextValues.removeValue(forKey: key)
        guard self.persist(nextValues) else { return }
        self.values = nextValues
    }

    private func update(_ value: JSONSettingsValue, forKey key: String) {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard self.values[key] != value else { return }

        var nextValues = self.values
        nextValues[key] = value
        guard self.persist(nextValues) else { return }
        self.values = nextValues
    }

    private func persist(_ values: [String: JSONSettingsValue]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(JSONSettingsPayload(values: values))
            try self.fileManager.createDirectory(
                at: self.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try DurableFileWriter.write(
                data,
                to: self.fileURL,
                fileManager: self.fileManager)
            return true
        } catch {
            return false
        }
    }

    private static func loadValues(from fileURL: URL) -> [String: JSONSettingsValue] {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(
                  JSONSettingsPayload.self,
                  from: data)
        else { return [:] }
        return payload.values
    }
}

private struct JSONSettingsPayload: Codable {
    let values: [String: JSONSettingsValue]
}

private enum JSONSettingsValue: Codable, Equatable {
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case stringArray([String])
    case date(Date)

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum ValueType: String, Codable {
        case bool
        case integer
        case double
        case string
        case stringArray
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ValueType.self, forKey: .type) {
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .integer:
            self = .integer(try container.decode(Int.self, forKey: .value))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .value))
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .stringArray:
            self = .stringArray(try container.decode([String].self, forKey: .value))
        case .date:
            self = .date(try container.decode(Date.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .bool(value):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .integer(value):
            try container.encode(ValueType.integer, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .double(value):
            try container.encode(ValueType.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .string(value):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .stringArray(value):
            try container.encode(ValueType.stringArray, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .date(value):
            try container.encode(ValueType.date, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}
