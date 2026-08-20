import Foundation
import Testing
import TokeniWindows

struct WindowsCompanionAssetCatalogTests {
    @Test
    func findsPortableResourceRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokeni-windows-assets-\(UUID().uuidString)")
        let resourceRoot = root
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("CompanionAssets", isDirectory: true)
        let marker = resourceRoot
            .appendingPathComponent("bytebot", isDirectory: true)
            .appendingPathComponent("manifest.json")
        try FileManager.default.createDirectory(
            at: marker.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: marker)
        defer { try? FileManager.default.removeItem(at: root) }

        let executableURL = root.appendingPathComponent("TokeniWindows.exe")
        #expect(
            WindowsCompanionAssetCatalog.assetRoot(for: executableURL)
                == resourceRoot)
    }

    @Test
    func ignoresDirectoriesWithoutManifestMarker() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokeni-windows-assets-\(UUID().uuidString)")
        let resourceRoot = root
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("CompanionAssets", isDirectory: true)
        try FileManager.default.createDirectory(
            at: resourceRoot,
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(
            WindowsCompanionAssetCatalog.assetRoot(
                for: root.appendingPathComponent("TokeniWindows.exe")) == nil)
    }
}
