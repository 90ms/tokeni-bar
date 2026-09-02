import Foundation
import Testing
@testable import TokeniCore

@Suite("Installed companion asset pack store")
struct InstalledCompanionAssetPackStoreTests {
    @Test("Only complete and self-consistent packs are listed")
    func listsValidPacksAndSkipsDamage() throws {
        let root = self.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let valid = try self.writePack(
            id: "codex.nebujelly",
            displayName: "Nebujelly",
            to: root)
        _ = try self.writePack(
            id: "codex.orbit-otter",
            displayName: "Orbit Otter",
            to: root,
            includeSpritesheet: false)
        let mismatched = try self.writePack(
            id: "codex.mismatched",
            displayName: "Mismatched",
            to: root)
        try FileManager.default.moveItem(
            at: mismatched,
            to: root.appending(
                path: "different-directory",
                directoryHint: .isDirectory))
        let store = InstalledCompanionAssetPackStore(installationRoot: root)

        let packs = store.installedPacks()

        #expect(packs.count == 1)
        #expect(packs[0].metadata.packID.rawValue == "codex.nebujelly")
        #expect(packs[0].directoryURL.resolvingSymlinksInPath()
            == valid.resolvingSymlinksInPath())
        #expect(store.assetSource().locations == [packs[0].assetLocation])
    }

    @Test("Removing a pack deletes assets without another state dependency")
    func removesOnlyRequestedPack() throws {
        let root = self.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try self.writePack(
            id: "codex.nebujelly",
            displayName: "Nebujelly",
            to: root)
        let second = try self.writePack(
            id: "codex.orbit-otter",
            displayName: "Orbit Otter",
            to: root)
        let store = InstalledCompanionAssetPackStore(installationRoot: root)

        try store.remove(packID: CompanionAssetPackID(
            rawValue: "codex.nebujelly"))

        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
        #expect(store.installedPacks().map(\.metadata.packID.rawValue)
            == ["codex.orbit-otter"])
        #expect(throws: InstalledCompanionAssetPackStoreError.packNotFound) {
            try store.remove(packID: CompanionAssetPackID(
                rawValue: "codex.unknown"))
        }
    }

    @Test("The default root stays inside Tokeni application support")
    func defaultRoot() {
        let base = URL(fileURLWithPath: "/test/Application Support")

        #expect(InstalledCompanionAssetPackStore.defaultInstallationRoot(
            applicationSupportDirectory: base)
            == base.appending(
                path: "CompanionPacks",
                directoryHint: .isDirectory))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "tokeni-installed-packs-\(UUID().uuidString)",
            directoryHint: .isDirectory)
    }

    @discardableResult
    private func writePack(
        id: String,
        displayName: String,
        to root: URL,
        includeSpritesheet: Bool = true) throws -> URL
    {
        let directory = root.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: directory.appending(path: "pet.json"))
        if includeSpritesheet {
            try Data("RIFF".utf8).write(
                to: directory.appending(path: "spritesheet.webp"))
        }
        let metadata = InstalledCompanionAssetPack(
            packID: CompanionAssetPackID(rawValue: id),
            speciesID: CompanionSpeciesID(rawValue: id),
            displayName: displayName,
            description: nil,
            format: .codexV1,
            spritesheetFileName: "spritesheet.webp",
            provenance: CompanionAssetPackProvenance(),
            installedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(metadata).write(to: directory.appending(
            path: InstalledCompanionAssetPack.metadataFileName))
        return directory
    }
}
