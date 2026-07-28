import Foundation

public actor CompanionRewardStateStore {
    private let fileURL: URL
    private var lastSavedRevision: UInt64 = 0

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-rewards.json")
    }

    public func load() throws -> CompanionRewardState {
        try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: Self.decode) ?? CompanionRewardState()
    }

    private static func decode(_ data: Data) throws -> CompanionRewardState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(CompanionRewardState.self, from: data),
              state.isValid()
        else {
            throw CompanionRewardStateStoreError.invalidState
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
        try RecoverableFileStorage.write(
            encoder.encode(state),
            to: self.fileURL)
        if let revision {
            self.lastSavedRevision = revision
        }
    }
}

private enum CompanionRewardStateStoreError: Error {
    case invalidState
}
