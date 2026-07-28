import Foundation

public actor CompanionRewardStateStore {
    private let fileURL: URL
    private var lastSavedRevision: UInt64 = 0

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-rewards.json")
    }

    public func load() throws -> CompanionRewardState {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
            return CompanionRewardState()
        }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(CompanionRewardState.self, from: data),
              state.isValid()
        else {
            try FileManager.default.removeItem(at: self.fileURL)
            return CompanionRewardState()
        }
        return state
    }

    public func save(
        _ state: CompanionRewardState,
        revision: UInt64? = nil) throws
    {
        guard state.isValid() else { return }
        if let revision, revision <= self.lastSavedRevision {
            return
        }
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: self.fileURL, options: .atomic)
        if let revision {
            self.lastSavedRevision = revision
        }
    }
}
