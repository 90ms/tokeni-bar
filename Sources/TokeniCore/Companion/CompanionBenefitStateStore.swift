import Foundation

public actor CompanionBenefitStateStore {
    private let fileURL: URL
    private var lastSavedRevision: UInt64 = 0

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-benefits.json")
    }

    public func load() throws -> CompanionBenefitState {
        try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: Self.decode) ?? CompanionBenefitState()
    }

    private static func decode(_ data: Data) throws -> CompanionBenefitState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(CompanionBenefitState.self, from: data),
              state.isValid()
        else {
            throw CompanionBenefitStateStoreError.invalidState
        }
        return state
    }

    public func save(
        _ state: CompanionBenefitState,
        revision: UInt64? = nil) throws
    {
        guard state.isValid() else { return }
        if let revision, revision <= self.lastSavedRevision { return }
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

private enum CompanionBenefitStateStoreError: Error {
    case invalidState
}
