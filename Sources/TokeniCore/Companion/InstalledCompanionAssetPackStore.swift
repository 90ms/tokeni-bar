import Foundation

public enum InstalledCompanionAssetPackStoreError:
    Error, Equatable, Sendable
{
    case packNotFound
    case removalFailed
}

public struct InstalledCompanionAssetPackStore: Sendable {
    public let installationRoot: URL

    public init(installationRoot: URL? = nil) {
        self.installationRoot = installationRoot
            ?? Self.defaultInstallationRoot()
    }

    public static func defaultInstallationRoot(
        applicationSupportDirectory: URL? = nil) -> URL
    {
        (applicationSupportDirectory
            ?? AppStoragePaths.applicationSupportDirectory())
            .appending(
                path: "CompanionPacks",
                directoryHint: .isDirectory)
    }

    /// Returns only complete, self-consistent installations. A damaged pack is
    /// unavailable rather than partially loaded or repaired with fabricated
    /// metadata.
    public func installedPacks() -> [CodexPetPackInstallation] {
        let fileManager = FileManager.default
        let directories = (try? fileManager.contentsOfDirectory(
            at: self.installationRoot,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ],
            options: [])) ?? []
        return directories.compactMap { directoryURL in
            guard !directoryURL.lastPathComponent.hasPrefix("."),
                  let values = try? directoryURL.resourceValues(forKeys: [
                      .isDirectoryKey,
                      .isSymbolicLinkKey,
                  ]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true,
                  let metadata = self.metadata(at: directoryURL),
                  metadata.packID.rawValue == directoryURL.lastPathComponent,
                  metadata.speciesID.rawValue.hasPrefix("codex."),
                  metadata.format == .codexV1 || metadata.format == .codexV2,
                  Self.isSupportedAssetName(metadata.spritesheetFileName),
                  self.isRegularFile(
                      directoryURL.appending(path: "pet.json")),
                  self.isRegularFile(directoryURL.appending(
                      path: metadata.spritesheetFileName))
            else { return nil }
            return CodexPetPackInstallation(
                metadata: metadata,
                directoryURL: directoryURL)
        }.sorted {
            if $0.metadata.displayName == $1.metadata.displayName {
                return $0.metadata.packID.rawValue
                    < $1.metadata.packID.rawValue
            }
            return $0.metadata.displayName.localizedStandardCompare(
                $1.metadata.displayName) == .orderedAscending
        }
    }

    public func assetSource() -> CompanionAssetSource {
        CompanionAssetSource(
            id: .localImports,
            kind: .localImport,
            locations: self.installedPacks().map(\.assetLocation))
    }

    public func remove(packID: CompanionAssetPackID) throws {
        guard let installation = self.installedPacks().first(where: {
            $0.metadata.packID == packID
        }) else { throw InstalledCompanionAssetPackStoreError.packNotFound }
        do {
            try FileManager.default.removeItem(at: installation.directoryURL)
        } catch {
            throw InstalledCompanionAssetPackStoreError.removalFailed
        }
    }

    private func metadata(at directoryURL: URL) -> InstalledCompanionAssetPack? {
        let metadataURL = directoryURL.appending(
            path: InstalledCompanionAssetPack.metadataFileName)
        guard self.isRegularFile(metadataURL),
              let data = try? Data(
                  contentsOf: metadataURL,
                  options: [.mappedIfSafe])
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(InstalledCompanionAssetPack.self, from: data)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]) else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func isSupportedAssetName(_ value: String) -> Bool {
        value == "spritesheet.webp" || value == "spritesheet.png"
    }
}
