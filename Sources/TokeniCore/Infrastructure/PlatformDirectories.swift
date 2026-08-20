import Foundation

public struct DefaultApplicationDirectoriesProvider: ApplicationDirectoriesProviding {
    public let directories: ApplicationDirectories

    public init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment)
    {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let applicationSupportFallback = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask).first
            ?? homeDirectory.appending(
                path: "Library/Application Support",
                directoryHint: .isDirectory)
        let cachesFallback = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask).first
            ?? homeDirectory.appending(
                path: "Library/Caches",
                directoryHint: .isDirectory)

        #if os(Windows)
        let applicationSupportDirectory = Self.environmentURL(
            named: "APPDATA",
            environment: environment,
            fallback: applicationSupportFallback)
        let localRoot = Self.environmentURL(
            named: "LOCALAPPDATA",
            environment: environment,
            fallback: cachesFallback)
        let cachesDirectory = localRoot.appending(
            path: "TokeniBar/Cache",
            directoryHint: .isDirectory)
        let localApplicationSupportDirectory = localRoot.appending(
            path: "TokeniBar",
            directoryHint: .isDirectory)
        #else
        let applicationSupportDirectory = applicationSupportFallback
        let cachesDirectory = cachesFallback
        let localApplicationSupportDirectory = applicationSupportDirectory
        #endif

        self.directories = ApplicationDirectories(
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory,
            cachesDirectory: cachesDirectory,
            localApplicationSupportDirectory: localApplicationSupportDirectory)
    }

    private static func environmentURL(
        named name: String,
        environment: [String: String],
        fallback: URL) -> URL
    {
        guard let path = environment[name], !path.isEmpty else { return fallback }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
