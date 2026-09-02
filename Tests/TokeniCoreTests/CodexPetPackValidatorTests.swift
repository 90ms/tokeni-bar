import Foundation
import Testing
@testable import TokeniCore

@Suite("Codex-compatible pet pack validator")
struct CodexPetPackValidatorTests {
    private let validator = CodexPetPackValidator()

    @Test("A V1 manifest without a version uses the 8 by 9 atlas")
    func validV1() throws {
        let validated = try self.validator.validate(
            manifestData: try self.fixture("codex-pet-v1-valid"),
            atlasPixelWidth: 1_536,
            atlasPixelHeight: 1_872)

        #expect(validated.manifest.id == "nebujelly")
        #expect(validated.packID.rawValue == "codex.nebujelly")
        #expect(validated.speciesID.rawValue == "codex.nebujelly")
        #expect(validated.format == .codexV1)
        #expect(validated.atlasColumns == 8)
        #expect(validated.atlasRows == 9)
        #expect(validated.frameWidth == 192)
        #expect(validated.frameHeight == 208)
    }

    @Test("A V2 manifest requires the 8 by 11 atlas")
    func validV2() throws {
        let validated = try self.validator.validate(
            manifestData: try self.fixture("codex-pet-v2-valid"),
            atlasPixelWidth: 1_536,
            atlasPixelHeight: 2_288)

        #expect(validated.format == .codexV2)
        #expect(validated.atlasRows == 11)
    }

    @Test("An unsafe spritesheet path is rejected")
    func rejectsPathTraversal() throws {
        #expect(throws: CodexPetPackValidationError(issues: [
            .unsafeSpritesheetPath,
        ])) {
            try self.validator.validate(
                manifestData: try self.fixture("codex-pet-unsafe-path"),
                atlasPixelWidth: 1_536,
                atlasPixelHeight: 1_872)
        }
    }

    @Test("Unsupported versions and dimensions report actionable issues")
    func rejectsVersionAndDimensions() throws {
        #expect(throws: CodexPetPackValidationError(issues: [
            .unsupportedSpriteVersion(3),
            .atlasSizeMismatch(
                expectedWidth: 1_536,
                expectedHeight: 1_872,
                actualWidth: 800,
                actualHeight: 600),
        ])) {
            try self.validator.validate(
                manifestData: try self.fixture("codex-pet-unsupported-version"),
                atlasPixelWidth: 800,
                atlasPixelHeight: 600)
        }
    }

    @Test("Malformed or oversized manifests fail before field validation")
    func rejectsMalformedManifest() throws {
        #expect(throws: CodexPetPackValidationError(issues: [
            .malformedManifest,
        ])) {
            try self.validator.validate(
                manifestData: try self.fixture("codex-pet-malformed"),
                atlasPixelWidth: 1_536,
                atlasPixelHeight: 1_872)
        }

        #expect(throws: CodexPetPackValidationError(issues: [
            .malformedManifest,
        ])) {
            try self.validator.validate(
                manifestData: Data(
                    repeating: 0,
                    count: CodexPetPackValidator.maximumManifestBytes + 1),
                atlasPixelWidth: 1_536,
                atlasPixelHeight: 1_872)
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
