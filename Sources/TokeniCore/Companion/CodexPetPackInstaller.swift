import Foundation

#if os(Windows)
import WinSDK
#endif

public struct CompanionAtlasPixelSize: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public protocol CompanionArchiveExtracting: Sendable {
    func extract(archiveURL: URL, to destinationURL: URL) async throws
}

public protocol CompanionAtlasInspecting: Sendable {
    func pixelSize(at imageURL: URL) throws -> CompanionAtlasPixelSize
}

public struct CompanionAssetPackProvenance: Codable, Equatable, Sendable {
    public let author: String?
    public let sourceURL: URL?
    public let licenseIdentifier: String?
    public let notice: String?

    public init(
        author: String? = nil,
        sourceURL: URL? = nil,
        licenseIdentifier: String? = nil,
        notice: String? = nil)
    {
        self.author = Self.normalized(author, maximumLength: 120)
        self.sourceURL = Self.safeSourceURL(sourceURL)
        self.licenseIdentifier = Self.normalized(
            licenseIdentifier,
            maximumLength: 120)
        self.notice = Self.normalized(notice, maximumLength: 2_000)
    }

    private static func normalized(
        _ value: String?,
        maximumLength: Int) -> String?
    {
        guard let normalized = value?.trimmingCharacters(
            in: .whitespacesAndNewlines),
            !normalized.isEmpty,
            normalized.count <= maximumLength
        else { return nil }
        return normalized
    }

    private static func safeSourceURL(_ url: URL?) -> URL? {
        guard let url,
              url.absoluteString.count <= 2_048,
              url.scheme?.lowercased() == "https"
                || url.scheme?.lowercased() == "http"
        else { return nil }
        return url
    }
}

public struct InstalledCompanionAssetPack: Codable, Equatable, Sendable {
    public static let metadataFileName = "tokeni-pack.json"

    public let packID: CompanionAssetPackID
    public let speciesID: CompanionSpeciesID
    public let displayName: String
    public let description: String?
    public let format: CompanionAssetFormat
    public let spritesheetFileName: String
    public let provenance: CompanionAssetPackProvenance
    public let installedAt: Date

    public init(
        packID: CompanionAssetPackID,
        speciesID: CompanionSpeciesID,
        displayName: String,
        description: String?,
        format: CompanionAssetFormat,
        spritesheetFileName: String,
        provenance: CompanionAssetPackProvenance,
        installedAt: Date)
    {
        self.packID = packID
        self.speciesID = speciesID
        self.displayName = displayName
        self.description = description
        self.format = format
        self.spritesheetFileName = spritesheetFileName
        self.provenance = provenance
        self.installedAt = installedAt
    }
}

public struct CodexPetPackInstallation: Equatable, Sendable {
    public let metadata: InstalledCompanionAssetPack
    public let directoryURL: URL

    public var assetLocation: CompanionAssetLocation {
        CompanionAssetLocation(
            sourceID: .localImports,
            packID: self.metadata.packID,
            speciesID: self.metadata.speciesID,
            format: self.metadata.format,
            directoryURL: self.directoryURL)
    }
}

public enum CodexPetPackInstallationError: Error, Equatable, Sendable {
    case archiveUnavailable
    case archiveInspection(ZIPArchiveInspectionError)
    case archiveValidation(CodexPetArchiveValidationError)
    case extractionFailed
    case unsafeExtractedContents
    case manifestUnavailable
    case atlasUnreadable
    case packValidation(CodexPetPackValidationError)
    case publishingFailed
}

public struct CodexPetPackInstaller: Sendable {
    private let installationRoot: URL
    private let extractor: any CompanionArchiveExtracting
    private let atlasInspector: any CompanionAtlasInspecting

    public init(
        installationRoot: URL,
        extractor: any CompanionArchiveExtracting,
        atlasInspector: any CompanionAtlasInspecting)
    {
        self.installationRoot = installationRoot
        self.extractor = extractor
        self.atlasInspector = atlasInspector
    }

    public func install(
        archiveURL: URL,
        provenance: CompanionAssetPackProvenance = .init(),
        installedAt: Date = .now) async throws -> CodexPetPackInstallation
    {
        let fileManager = FileManager.default
        guard let archiveSize = try? archiveURL.resourceValues(
            forKeys: [.fileSizeKey]).fileSize,
            archiveSize <= CodexPetArchiveValidator.maximumCompressedBytes,
            let archiveData = try? Data(
                contentsOf: archiveURL,
                options: [.mappedIfSafe])
        else { throw CodexPetPackInstallationError.archiveUnavailable }

        let entries: [CompanionArchiveEntry]
        do {
            entries = try ZIPArchiveInspector().inspect(archiveData)
        } catch let error as ZIPArchiveInspectionError {
            throw CodexPetPackInstallationError.archiveInspection(error)
        } catch {
            throw CodexPetPackInstallationError.archiveUnavailable
        }
        let archive: ValidatedCodexPetArchive
        do {
            archive = try CodexPetArchiveValidator().validate(
                entries: entries,
                archiveByteCount: archiveData.count)
        } catch let error as CodexPetArchiveValidationError {
            throw CodexPetPackInstallationError.archiveValidation(error)
        } catch {
            throw CodexPetPackInstallationError.archiveUnavailable
        }

        do {
            try fileManager.createDirectory(
                at: self.installationRoot,
                withIntermediateDirectories: true)
        } catch {
            throw CodexPetPackInstallationError.publishingFailed
        }
        let stagingURL = self.installationRoot.appending(
            path: ".staging-\(UUID().uuidString)",
            directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: stagingURL) }
        do {
            try fileManager.createDirectory(
                at: stagingURL,
                withIntermediateDirectories: false)
            try await self.extractor.extract(
                archiveURL: archiveURL,
                to: stagingURL)
        } catch {
            throw CodexPetPackInstallationError.extractionFailed
        }

        guard try self.hasExpectedExtractedContents(
            archive: archive,
            at: stagingURL)
        else {
            throw CodexPetPackInstallationError.unsafeExtractedContents
        }
        let manifestURL = stagingURL.appending(path: archive.manifestPath)
        guard let manifestData = try? Data(
            contentsOf: manifestURL,
            options: [.mappedIfSafe]),
            manifestData.count <= CodexPetPackValidator.maximumManifestBytes
        else { throw CodexPetPackInstallationError.manifestUnavailable }
        let decodedManifest = try? JSONDecoder().decode(
            CodexPetManifest.self,
            from: manifestData)
        guard decodedManifest?.spritesheetPath == archive.spritesheetPath else {
            throw CodexPetPackInstallationError.unsafeExtractedContents
        }
        let spritesheetURL = stagingURL.appending(path: archive.spritesheetPath)
        let pixelSize: CompanionAtlasPixelSize
        do {
            pixelSize = try self.atlasInspector.pixelSize(at: spritesheetURL)
        } catch {
            throw CodexPetPackInstallationError.atlasUnreadable
        }
        let validatedPack: ValidatedCodexPetPack
        do {
            validatedPack = try CodexPetPackValidator().validate(
                manifestData: manifestData,
                atlasPixelWidth: pixelSize.width,
                atlasPixelHeight: pixelSize.height)
        } catch let error as CodexPetPackValidationError {
            throw CodexPetPackInstallationError.packValidation(error)
        } catch {
            throw CodexPetPackInstallationError.manifestUnavailable
        }

        let metadata = InstalledCompanionAssetPack(
            packID: validatedPack.packID,
            speciesID: validatedPack.speciesID,
            displayName: validatedPack.manifest.displayName,
            description: validatedPack.manifest.description,
            format: validatedPack.format,
            spritesheetFileName: archive.spritesheetPath,
            provenance: provenance,
            installedAt: installedAt)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(metadata).write(
                to: stagingURL.appending(
                    path: InstalledCompanionAssetPack.metadataFileName),
                options: [.atomic])
        } catch {
            throw CodexPetPackInstallationError.publishingFailed
        }

        let destinationURL = self.installationRoot.appending(
            path: validatedPack.packID.rawValue,
            directoryHint: .isDirectory)
        do {
            try self.publish(
                stagingURL: stagingURL,
                destinationURL: destinationURL)
        } catch {
            throw CodexPetPackInstallationError.publishingFailed
        }
        return CodexPetPackInstallation(
            metadata: metadata,
            directoryURL: destinationURL)
    }

    private func hasExpectedExtractedContents(
        archive: ValidatedCodexPetArchive,
        at directoryURL: URL) throws -> Bool
    {
        let expected = Set([archive.manifestPath, archive.spritesheetPath])
        let contents = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [])
        guard Set(contents.map(\.lastPathComponent)) == expected else {
            return false
        }
        let entriesByPath = Dictionary(
            uniqueKeysWithValues: archive.entries.map { ($0.path, $0) })
        return try contents.allSatisfy { url in
            // swift-corelibs-foundation on Windows can omit both the URL
            // resource-value and FileManager attribute used to label an
            // ordinary file. Check the properties that are consistently
            // available after the archive's entry types have been validated.
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: url.path,
                isDirectory: &isDirectory)
            guard exists,
                  !isDirectory.boolValue,
                  !Self.isSymbolicLinkOrReparsePoint(at: url),
                  let size = try? Data(
                    contentsOf: url,
                    options: [.mappedIfSafe]).count,
                  let expectedEntry = entriesByPath[url.lastPathComponent]
            else { return false }
            return size == expectedEntry.uncompressedSize
        }
    }

    private static func isSymbolicLinkOrReparsePoint(at url: URL) -> Bool {
        #if os(Windows)
        let attributes = url.path.withCString(encodedAs: UTF16.self) {
            GetFileAttributesW($0)
        }
        guard attributes != DWORD(INVALID_FILE_ATTRIBUTES) else { return true }
        return attributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0
        #else
        return (try? FileManager.default.destinationOfSymbolicLink(
            atPath: url.path)) != nil
        #endif
    }

    private func publish(stagingURL: URL, destinationURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            let backupName = ".backup-\(UUID().uuidString)"
            _ = try fileManager.replaceItemAt(
                destinationURL,
                withItemAt: stagingURL,
                backupItemName: backupName,
                options: [])
            let backupURL = self.installationRoot.appending(path: backupName)
            try? fileManager.removeItem(at: backupURL)
        } else {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
        }
    }
}
