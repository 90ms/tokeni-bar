import Foundation

enum RecoverableFileStorage {
    static let maximumBackupCount = 3

    static func load<Value>(
        from fileURL: URL,
        fileManager: FileManager = .default,
        decode: (Data) throws -> Value) throws -> Value?
    {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try decode(Data(contentsOf: fileURL))
        } catch {
            try self.quarantine(fileURL, fileManager: fileManager)
        }

        for backupURL in self.backupURLs(for: fileURL) {
            guard let data = try? Data(contentsOf: backupURL),
                  let value = try? decode(data)
            else { continue }
            try data.write(to: fileURL, options: .atomic)
            return value
        }
        return nil
    }

    static func write(
        _ data: Data,
        to fileURL: URL,
        fileManager: FileManager = .default) throws
    {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try self.rotateBackups(for: fileURL, fileManager: fileManager)
        try data.write(to: fileURL, options: .atomic)
    }

    static func backupURLs(for fileURL: URL) -> [URL] {
        (1...self.maximumBackupCount).map {
            URL(fileURLWithPath: "\(fileURL.path).backup-\($0)")
        }
    }

    static func removePrimaryAndBackups(
        for fileURL: URL,
        fileManager: FileManager = .default) throws
    {
        for url in [fileURL] + self.backupURLs(for: fileURL)
            where fileManager.fileExists(atPath: url.path)
        {
            try fileManager.removeItem(at: url)
        }
    }

    @discardableResult
    static func quarantine(
        _ fileURL: URL,
        fileManager: FileManager = .default) throws -> URL
    {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let pathExtension = fileURL.pathExtension
        let suffix = "\(Int(Date.now.timeIntervalSince1970))-\(UUID().uuidString)"
        let quarantineName = pathExtension.isEmpty
            ? "\(fileName).corrupt-\(suffix)"
            : "\(fileName).corrupt-\(suffix).\(pathExtension)"
        let quarantineURL = fileURL.deletingLastPathComponent()
            .appending(path: quarantineName)
        try fileManager.moveItem(at: fileURL, to: quarantineURL)
        return quarantineURL
    }

    private static func rotateBackups(
        for fileURL: URL,
        fileManager: FileManager) throws
    {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let backups = self.backupURLs(for: fileURL)
        if let oldest = backups.last,
           fileManager.fileExists(atPath: oldest.path)
        {
            try fileManager.removeItem(at: oldest)
        }
        for index in stride(from: backups.count - 1, through: 1, by: -1) {
            let source = backups[index - 1]
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.moveItem(at: source, to: backups[index])
        }
        try fileManager.copyItem(at: fileURL, to: backups[0])
    }
}
