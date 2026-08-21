import Foundation

enum RecoverableFileStorage {
    static let maximumBackupCount = 3

    static func load<Value>(
        from fileURL: URL,
        fileManager: FileManager = .default,
        decode: (Data) throws -> Value) throws -> Value?
    {
        try self.load(
            from: fileURL,
            fileManager: fileManager,
            quarantinePrimary: { fileURL, fileManager in
                _ = try self.quarantine(fileURL, fileManager: fileManager)
            },
            decode: decode)
    }

    static func load<Value>(
        from fileURL: URL,
        fileManager: FileManager = .default,
        quarantinePrimary: (URL, FileManager) throws -> Void,
        decode: (Data) throws -> Value) throws -> Value?
    {
        let primaryExisted = fileManager.fileExists(atPath: fileURL.path)
        var primaryWasQuarantined = false
        var quarantineError: Error?
        if primaryExisted {
            do {
                return try decode(Data(contentsOf: fileURL))
            } catch {
                do {
                    try quarantinePrimary(fileURL, fileManager)
                    primaryWasQuarantined = true
                } catch {
                    quarantineError = error
                }
            }
        }

        for backupURL in self.backupURLs(for: fileURL) {
            guard let data = try? Data(contentsOf: backupURL),
                  let value = try? decode(data)
            else { continue }
            if !primaryExisted || primaryWasQuarantined {
                try DurableFileWriter.write(
                    data,
                    to: fileURL,
                    fileManager: fileManager)
            }
            return value
        }
        if let quarantineError { throw quarantineError }
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
        try DurableFileWriter.write(
            data,
            to: fileURL,
            fileManager: fileManager)
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
        try self.removePrimaryAndBackups(
            for: fileURL,
            fileManager: fileManager,
            removeItem: { try fileManager.removeItem(at: $0) })
    }

    static func removePrimaryAndBackups(
        for fileURL: URL,
        fileManager: FileManager = .default,
        removeItem: (URL) throws -> Void) throws
    {
        // Remove recovery sources first so an interrupted clear always leaves
        // the current primary in place instead of reviving an older backup.
        for url in self.backupURLs(for: fileURL)
            + self.quarantineURLs(for: fileURL, fileManager: fileManager)
            + [fileURL]
            where fileManager.fileExists(atPath: url.path)
        {
            try removeItem(url)
        }
    }

    static func hasQuarantinedFile(
        for fileURL: URL,
        fileManager: FileManager = .default) -> Bool
    {
        !self.quarantineURLs(
            for: fileURL,
            fileManager: fileManager).isEmpty
    }

    static func quarantineURLs(
        for fileURL: URL,
        fileManager: FileManager = .default) -> [URL]
    {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let pathExtension = fileURL.pathExtension
        let prefix = "\(fileName).corrupt-"
        return (try? fileManager.contentsOfDirectory(
            at: fileURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil))?.filter { candidate in
                candidate.lastPathComponent.hasPrefix(prefix)
                    && (pathExtension.isEmpty
                        || candidate.pathExtension == pathExtension)
            } ?? []
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
