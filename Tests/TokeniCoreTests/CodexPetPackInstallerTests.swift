import Foundation
import Testing
@testable import TokeniCore

@Suite("Codex pet pack installer")
struct CodexPetPackInstallerTests {
    @Test("A validated pack installs with provenance and a local asset location")
    func installsValidatedPack() async throws {
        let environment = try self.environment()
        defer { try? FileManager.default.removeItem(at: environment.root) }
        let installedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let installer = CodexPetPackInstaller(
            installationRoot: environment.installationRoot,
            extractor: FixtureArchiveExtractor(
                manifestData: environment.manifestData),
            atlasInspector: FixedAtlasInspector(
                size: CompanionAtlasPixelSize(width: 1_536, height: 1_872)))

        let installed = try await installer.install(
            archiveURL: environment.archiveURL,
            provenance: CompanionAssetPackProvenance(
                author: "Fixture Artist",
                sourceURL: URL(string: "https://example.test/nebujelly"),
                licenseIdentifier: "CC-BY-4.0"),
            installedAt: installedAt)

        #expect(installed.metadata.packID.rawValue == "codex.nebujelly")
        #expect(installed.metadata.provenance.author == "Fixture Artist")
        #expect(installed.metadata.installedAt == installedAt)
        #expect(installed.assetLocation.format == .codexV1)
        #expect(FileManager.default.fileExists(atPath: installed.directoryURL
            .appending(path: "pet.json").path))
        #expect(FileManager.default.fileExists(atPath: installed.directoryURL
            .appending(path: "spritesheet.webp").path))
        #expect(FileManager.default.fileExists(atPath: installed.directoryURL
            .appending(path: InstalledCompanionAssetPack.metadataFileName).path))
        let metadataData = try Data(contentsOf: installed.directoryURL.appending(
            path: InstalledCompanionAssetPack.metadataFileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(
            InstalledCompanionAssetPack.self,
            from: metadataData) == installed.metadata)

        let oldSentinel = installed.directoryURL.appending(path: "existing.txt")
        try Data("old".utf8).write(to: oldSentinel)
        let replaced = try await installer.install(
            archiveURL: environment.archiveURL,
            provenance: CompanionAssetPackProvenance(author: "Updated Artist"),
            installedAt: installedAt.addingTimeInterval(60))
        #expect(replaced.directoryURL == installed.directoryURL)
        #expect(replaced.metadata.provenance.author == "Updated Artist")
        #expect(!FileManager.default.fileExists(atPath: oldSentinel.path))
    }

    @Test("A bad atlas leaves an existing installation untouched")
    func validationFailurePreservesExistingPack() async throws {
        let environment = try self.environment()
        defer { try? FileManager.default.removeItem(at: environment.root) }
        let existing = environment.installationRoot.appending(
            path: "codex.nebujelly",
            directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: existing,
            withIntermediateDirectories: true)
        let sentinel = existing.appending(path: "existing.txt")
        try Data("keep".utf8).write(to: sentinel)
        let installer = CodexPetPackInstaller(
            installationRoot: environment.installationRoot,
            extractor: FixtureArchiveExtractor(
                manifestData: environment.manifestData),
            atlasInspector: FixedAtlasInspector(
                size: CompanionAtlasPixelSize(width: 800, height: 600)))

        await #expect(throws: CodexPetPackInstallationError.packValidation(
            CodexPetPackValidationError(issues: [
                .atlasSizeMismatch(
                    expectedWidth: 1_536,
                    expectedHeight: 1_872,
                    actualWidth: 800,
                    actualHeight: 600),
            ]))) {
            try await installer.install(archiveURL: environment.archiveURL)
        }

        #expect(try String(contentsOf: sentinel, encoding: .utf8) == "keep")
        let staging = try FileManager.default.contentsOfDirectory(
            at: environment.installationRoot,
            includingPropertiesForKeys: nil).filter {
                $0.lastPathComponent.hasPrefix(".staging-")
            }
        #expect(staging.isEmpty)
    }

    @Test("Unsafe provenance values are not persisted")
    func sanitizesProvenance() {
        let provenance = CompanionAssetPackProvenance(
            author: "   ",
            sourceURL: URL(string: "file:///private/source"),
            licenseIdentifier: String(repeating: "x", count: 121),
            notice: " Local use only ")

        #expect(provenance.author == nil)
        #expect(provenance.sourceURL == nil)
        #expect(provenance.licenseIdentifier == nil)
        #expect(provenance.notice == "Local use only")
    }

    @Test("Unexpected extracted files fail closed and clean staging")
    func rejectsUnexpectedExtractedFiles() async throws {
        try await self.expectUnsafeExtraction(
            .unexpectedFile,
            issue: .unexpectedFilenames)
    }

    @Test("Extracted directories fail closed and clean staging")
    func rejectsExtractedDirectories() async throws {
        try await self.expectUnsafeExtraction(
            .manifestDirectory,
            issue: .directory)
    }

    @Test("Extracted byte mismatches fail closed and clean staging")
    func rejectsExtractedSizeMismatch() async throws {
        try await self.expectUnsafeExtraction(
            .manifestSizeMismatch,
            issue: .sizeMismatch)
    }

    @Test("Manifest asset mismatches fail closed and clean staging")
    func rejectsManifestAssetMismatch() async throws {
        try await self.expectUnsafeExtraction(
            .manifestAssetMismatch,
            issue: .manifestAssetMismatch)
    }

    #if !os(Windows)
    @Test("Extracted symbolic links fail closed and clean staging")
    func rejectsExtractedSymbolicLinks() async throws {
        try await self.expectUnsafeExtraction(
            .manifestSymbolicLink,
            issue: .linkOrReparsePoint)
    }
    #endif

    private func expectUnsafeExtraction(
        _ mutation: FixtureExtractionMutation,
        issue: CodexPetPackExtractedContentsIssue) async throws
    {
        let environment = try self.environment()
        defer { try? FileManager.default.removeItem(at: environment.root) }
        let installer = CodexPetPackInstaller(
            installationRoot: environment.installationRoot,
            extractor: FixtureArchiveExtractor(
                manifestData: environment.manifestData,
                mutation: mutation),
            atlasInspector: FixedAtlasInspector(
                size: CompanionAtlasPixelSize(width: 1_536, height: 1_872)))

        await #expect(throws:
            CodexPetPackInstallationError.unsafeExtractedContents(issue)
        ) {
            try await installer.install(archiveURL: environment.archiveURL)
        }

        let remaining = try FileManager.default.contentsOfDirectory(
            at: environment.installationRoot,
            includingPropertiesForKeys: nil)
        #expect(remaining.isEmpty)
    }

    private func environment() throws -> InstallerTestEnvironment {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "tokeni-pack-installer-\(UUID().uuidString)",
            directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        let archiveURL = root.appending(path: "nebujelly.codex-pet.zip")
        try self.archiveFixture().write(to: archiveURL)
        return InstallerTestEnvironment(
            root: root,
            installationRoot: root.appending(
                path: "installed",
                directoryHint: .isDirectory),
            archiveURL: archiveURL,
            manifestData: try self.fixture(
                "codex-pet-v1-valid",
                extension: "json"))
    }

    private func archiveFixture() throws -> Data {
        let encoded = try self.fixture(
            "codex-pet-archive-valid",
            extension: "base64")
        let string = String(decoding: encoded, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try #require(Data(base64Encoded: string))
    }

    private func fixture(_ name: String, extension: String) throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: name,
            withExtension: `extension`,
            subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

private struct InstallerTestEnvironment {
    let root: URL
    let installationRoot: URL
    let archiveURL: URL
    let manifestData: Data
}

private struct FixtureArchiveExtractor: CompanionArchiveExtracting {
    let manifestData: Data
    var mutation: FixtureExtractionMutation = .none

    func extract(archiveURL: URL, to destinationURL: URL) async throws {
        let manifestURL = destinationURL.appending(path: "pet.json")
        switch self.mutation {
        case .none, .unexpectedFile:
            try self.manifestData.write(to: manifestURL)
        case .manifestDirectory:
            try FileManager.default.createDirectory(
                at: manifestURL,
                withIntermediateDirectories: false)
        case .manifestSizeMismatch:
            var oversizedManifest = self.manifestData
            oversizedManifest.append(UInt8(ascii: "\n"))
            try oversizedManifest.write(to: manifestURL)
        case .manifestAssetMismatch:
            let mismatched = String(decoding: self.manifestData, as: UTF8.self)
                .replacingOccurrences(
                    of: "spritesheet.webp",
                    with: "spritesheet.zzzz")
            try Data(mismatched.utf8).write(to: manifestURL)
        case .manifestSymbolicLink:
            try FileManager.default.createSymbolicLink(
                at: manifestURL,
                withDestinationURL: archiveURL)
        }
        try Data("RIFF".utf8).write(
            to: destinationURL.appending(path: "spritesheet.webp"))
        if self.mutation == .unexpectedFile {
            try Data().write(to: destinationURL.appending(path: "extra.bin"))
        }
    }
}

private enum FixtureExtractionMutation: Equatable, Sendable {
    case none
    case unexpectedFile
    case manifestDirectory
    case manifestSizeMismatch
    case manifestAssetMismatch
    case manifestSymbolicLink
}

private struct FixedAtlasInspector: CompanionAtlasInspecting {
    let size: CompanionAtlasPixelSize

    func pixelSize(at _: URL) throws -> CompanionAtlasPixelSize {
        self.size
    }
}
