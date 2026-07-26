@testable import TokeniCore
import Foundation
import Testing

struct PricingCatalogTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_768_521_600)

    @Test
    func bundledCatalogPreservesExistingPricingAPI() throws {
        let metadata = TokenPricingCatalog.metadata
        let sol = try #require(TokenPricingCatalog.pricing(
            providerID: .codex,
            modelID: "gpt-5.6-sol"))
        let sonnet = try #require(TokenPricingCatalog.pricing(
            providerID: .claude,
            modelID: "claude-sonnet-4-6"))

        #expect(metadata.schemaVersion == 1)
        #expect(metadata.catalogVersion >= 1)
        #expect(sol.inputPerMillion == 5)
        #expect(sol.cachedInputPerMillion == 0.5)
        #expect(sol.outputPerMillion == 30)
        #expect(sonnet.inputPerMillion == 3)
        #expect(sonnet.outputPerMillion == 15)
    }

    @Test
    func rejectsUnsupportedSchemaFutureDatesAndUntrustedSources() {
        #expect(throws: PricingCatalogValidationError.unsupportedSchema(2)) {
            try TokenPricingCatalog.validate(self.manifest(schemaVersion: 2), at: self.referenceDate)
        }
        #expect(throws: PricingCatalogValidationError.publishedInFuture) {
            try TokenPricingCatalog.validate(
                self.manifest(publishedAt: self.referenceDate.addingTimeInterval(2 * 24 * 60 * 60)),
                at: self.referenceDate)
        }
        #expect(throws: PricingCatalogValidationError.invalidEffectiveDate) {
            try TokenPricingCatalog.validate(
                self.manifest(effectiveDate: "2026-99-99"),
                at: self.referenceDate)
        }
        #expect(throws: PricingCatalogValidationError.untrustedSource("test-model")) {
            try TokenPricingCatalog.validate(
                self.manifest(sourceURL: URL(string: "https://example.com/pricing")!),
                at: self.referenceDate)
        }
    }

    @Test
    func rejectsUnsafePricesAndOverlappingWindows() {
        #expect(throws: PricingCatalogValidationError.invalidPricing("test-model")) {
            try TokenPricingCatalog.validate(
                self.manifest(inputPrice: .infinity),
                at: self.referenceDate)
        }

        let first = self.model(
            id: "first",
            effectiveUntil: self.referenceDate.addingTimeInterval(60 * 60))
        let second = self.model(
            id: "second",
            effectiveFrom: self.referenceDate)
        #expect(throws: PricingCatalogValidationError.overlappingEffectiveWindows("second")) {
            try TokenPricingCatalog.validate(
                self.manifest(models: [first, second]),
                at: self.referenceDate)
        }
    }

    @Test
    func rejectsDowngradesAndSameVersionContentChanges() {
        let current = self.manifest(version: 3)
        let downgrade = self.manifest(version: 2)
        let conflict = self.manifest(version: 3, inputPrice: 99)

        #expect(throws: PricingCatalogValidationError.downgrade(current: 3, candidate: 2)) {
            try TokenPricingCatalog.validateUpdate(downgrade, replacing: current)
        }
        #expect(throws: PricingCatalogValidationError.versionConflict(3)) {
            try TokenPricingCatalog.validateUpdate(conflict, replacing: current)
        }
    }

    @Test
    func invalidCacheFallsBackWithoutChangingActiveCatalog() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cacheURL = directory.appending(path: "token-pricing.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: cacheURL)
        let metadataBefore = TokenPricingCatalog.metadata
        let client = PricingCatalogUpdateClient(cacheURL: cacheURL)

        let result = await client.activateCachedCatalog(at: self.referenceDate)

        #expect(result.source == .bundled)
        #expect(result.didActivateNewVersion == false)
        #expect(TokenPricingCatalog.metadata == metadataBefore)
    }

    private func manifest(
        schemaVersion: Int = 1,
        version: Int = 1,
        publishedAt: Date? = nil,
        effectiveDate: String = "2026-01-15",
        inputPrice: Double = 1,
        sourceURL: URL = URL(string: "https://developers.openai.com/api/docs/models")!,
        models: [PricingCatalogManifest.Model]? = nil) -> PricingCatalogManifest
    {
        PricingCatalogManifest(
            schemaVersion: schemaVersion,
            catalogVersion: version,
            publishedAt: publishedAt ?? self.referenceDate,
            effectiveDate: effectiveDate,
            models: models ?? [self.model(inputPrice: inputPrice, sourceURL: sourceURL)])
    }

    private func model(
        id: String = "test-model",
        inputPrice: Double = 1,
        effectiveFrom: Date? = nil,
        effectiveUntil: Date? = nil,
        sourceURL: URL = URL(string: "https://developers.openai.com/api/docs/models")!)
        -> PricingCatalogManifest.Model
    {
        PricingCatalogManifest.Model(
            id: id,
            providerID: .codex,
            matchKind: .exact,
            modelPattern: "test-model",
            effectiveFrom: effectiveFrom,
            effectiveUntil: effectiveUntil,
            pricing: ModelTokenPricing(
                inputPerMillion: inputPrice,
                cachedInputPerMillion: 0.1,
                outputPerMillion: 2),
            sourceURL: sourceURL)
    }
}
