import Foundation

public actor CompanionGameStateStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-state.json")
    }

    public func load() throws -> CompanionGameState {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
            return CompanionGameState()
        }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(CompanionGameState.self, from: data),
              state.isValid()
        else {
            try FileManager.default.removeItem(at: self.fileURL)
            return CompanionGameState()
        }
        return state
    }

    public func save(_ state: CompanionGameState) throws {
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: self.fileURL, options: .atomic)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        try FileManager.default.removeItem(at: self.fileURL)
    }
}
