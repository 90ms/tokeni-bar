import Foundation
import Testing
@testable import TokeniCore

@Suite("Codex pet ZIP archives")
struct CodexPetArchiveTests {
    @Test("A sanitized two-file ZIP fixture passes inspection and policy")
    func validArchiveFixture() throws {
        let archiveData = try self.archiveFixture()
        let entries = try ZIPArchiveInspector().inspect(archiveData)
        let validated = try CodexPetArchiveValidator().validate(
            entries: entries,
            archiveByteCount: archiveData.count)

        #expect(entries.map(\.path) == ["pet.json", "spritesheet.webp"])
        #expect(validated.manifestPath == "pet.json")
        #expect(validated.spritesheetPath == "spritesheet.webp")
    }

    @Test("Unsafe, linked, encrypted, and extra fixture entries are rejected")
    func rejectsUnsafeFixtureEntries() throws {
        let entries = try JSONDecoder().decode(
            [CompanionArchiveEntry].self,
            from: self.fixture("codex-pet-archive-unsafe", extension: "json"))

        do {
            _ = try CodexPetArchiveValidator().validate(
                entries: entries,
                archiveByteCount: 1_024)
            Issue.record("Expected unsafe archive entries to fail")
        } catch let error as CodexPetArchiveValidationError {
            #expect(error.issues.contains(.unsafePath("../pet.json")))
            #expect(error.issues.contains(.symbolicLink("spritesheet.webp")))
            #expect(error.issues.contains(.encryptedEntry("secret.bin")))
            #expect(error.issues.contains(.unsupportedCompressionMethod(
                path: "secret.bin",
                method: 99)))
            #expect(error.issues.contains(.unsupportedFile("secret.bin")))
        }
    }

    @Test("Malformed ZIP data fails before extraction")
    func rejectsMalformedArchive() {
        #expect(throws: ZIPArchiveInspectionError.malformedArchive) {
            try ZIPArchiveInspector().inspect(Data("not-a-zip".utf8))
        }
    }

    @Test("A local filename that conflicts with the central directory fails")
    func rejectsConflictingLocalFilename() throws {
        var archiveData = try self.archiveFixture()
        archiveData[archiveData.startIndex + 30] = 120

        #expect(throws:
            ZIPArchiveInspectionError.centralAndLocalHeaderMismatch)
        {
            try ZIPArchiveInspector().inspect(archiveData)
        }
    }

    @Test("Expansion and compression-ratio limits reject archive bombs")
    func rejectsArchiveBombMetadata() {
        let entries = [
            CompanionArchiveEntry(
                path: "pet.json",
                compressedSize: 20,
                uncompressedSize: 100),
            CompanionArchiveEntry(
                path: "spritesheet.webp",
                compressedSize: 1,
                uncompressedSize: CodexPetArchiveValidator
                    .maximumExpandedBytes + 1),
        ]

        do {
            _ = try CodexPetArchiveValidator().validate(
                entries: entries,
                archiveByteCount: 100)
            Issue.record("Expected archive-bomb metadata to fail")
        } catch let error as CodexPetArchiveValidationError {
            #expect(error.issues.contains(.expandedArchiveTooLarge(
                maximumBytes: CodexPetArchiveValidator.maximumExpandedBytes)))
            #expect(error.issues.contains(.suspiciousCompressionRatio(
                "spritesheet.webp")))
        }
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
