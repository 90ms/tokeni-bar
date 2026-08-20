import Foundation

public enum AppStoragePaths {
    public static let directoryName = "TokeniBar"
    public static let legacyDirectoryName = "AgentsStatusBar"

    public static func applicationSupportDirectory(
        baseURL: URL? = nil,
        fileManager: FileManager = .default,
        directories: ApplicationDirectories? = nil) -> URL
    {
        let baseURL = baseURL
            ?? directories?.applicationSupportDirectory
            ?? DefaultApplicationDirectoriesProvider(fileManager: fileManager)
                .directories.applicationSupportDirectory
        let currentURL = baseURL.appending(
            path: self.directoryName,
            directoryHint: .isDirectory)
        let legacyURL = baseURL.appending(
            path: self.legacyDirectoryName,
            directoryHint: .isDirectory)

        guard !fileManager.fileExists(atPath: currentURL.path),
              fileManager.fileExists(atPath: legacyURL.path)
        else {
            return currentURL
        }

        do {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
            try fileManager.moveItem(at: legacyURL, to: currentURL)
            return currentURL
        } catch {
            return legacyURL
        }
    }
}
