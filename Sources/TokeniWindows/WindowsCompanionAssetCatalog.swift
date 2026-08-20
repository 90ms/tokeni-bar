import Foundation

/// Locates the companion asset tree next to a portable Windows executable.
/// The catalog contains only visual companion resources; it is independent of
/// provider usage, token totals, prompts, and response content.
public enum WindowsCompanionAssetCatalog {
    private static let companionDirectoryName = "CompanionAssets"
    private static let markerPath = ["bytebot", "manifest.json"]

    public static func assetRoot(for executableURL: URL) -> URL? {
        let executableDirectory = executableURL.deletingLastPathComponent()
        let candidates = [
            executableDirectory
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(self.companionDirectoryName, isDirectory: true),
            executableDirectory.appendingPathComponent(
                self.companionDirectoryName,
                isDirectory: true),
        ]
        return candidates.first { candidate in
            let marker = self.markerPath.reduce(candidate) {
                $0.appendingPathComponent($1)
            }
            return FileManager.default.fileExists(
                atPath: marker.path,
                isDirectory: nil)
        }
    }
}
