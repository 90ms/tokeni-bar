import Foundation

public struct SystemExecutableLocator: ExecutableLocating {
    public init() {}

    public func locate(
        executableNames: [String],
        pathEnvironment: String?,
        homeDirectory: URL) -> URL?
    {
        var searchDirectories = PlatformEnvironment.pathEntries(pathEnvironment)
        searchDirectories.append(
            homeDirectory.appending(path: ".local/bin", directoryHint: .isDirectory).path)
        searchDirectories.append(
            homeDirectory.appending(path: ".npm-global/bin", directoryHint: .isDirectory).path)

        for directory in searchDirectories where !directory.isEmpty {
            for executableName in executableNames {
                for candidate in self.candidateNames(for: executableName) {
                    let url = URL(fileURLWithPath: directory, isDirectory: true)
                        .appending(path: candidate)
                    if self.isRunnable(url) {
                        return url
                    }
                }
            }
        }

        return nil
    }

    private func candidateNames(for name: String) -> [String] {
        #if os(Windows)
        guard URL(fileURLWithPath: name).pathExtension.isEmpty else { return [name] }
        return [name, "\(name).exe", "\(name).cmd", "\(name).bat"]
        #else
        return [name]
        #endif
    }

    private func isRunnable(_ url: URL) -> Bool {
        #if os(Windows)
        return FileManager.default.fileExists(atPath: url.path)
        #else
        return FileManager.default.isExecutableFile(atPath: url.path)
        #endif
    }
}
