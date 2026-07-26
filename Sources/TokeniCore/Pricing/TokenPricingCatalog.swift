import Foundation

public struct ModelTokenPricing: Codable, Hashable, Sendable {
    public let inputPerMillion: Double
    public let cacheCreationPerMillion: Double?
    public let cacheCreation1hPerMillion: Double?
    public let cachedInputPerMillion: Double
    public let outputPerMillion: Double

    public init(
        inputPerMillion: Double,
        cacheCreationPerMillion: Double? = nil,
        cacheCreation1hPerMillion: Double? = nil,
        cachedInputPerMillion: Double,
        outputPerMillion: Double)
    {
        self.inputPerMillion = inputPerMillion
        self.cacheCreationPerMillion = cacheCreationPerMillion
        self.cacheCreation1hPerMillion = cacheCreation1hPerMillion
        self.cachedInputPerMillion = cachedInputPerMillion
        self.outputPerMillion = outputPerMillion
    }

    public func estimate(_ usage: TokenUsage) -> Double {
        let input = Double(usage.inputTokens ?? 0) * self.inputPerMillion
        let cacheCreation = Double(usage.cacheCreationInputTokens ?? 0)
            * (self.cacheCreationPerMillion ?? self.inputPerMillion)
        let cacheCreation1h = Double(usage.cacheCreation1hInputTokens ?? 0)
            * (self.cacheCreation1hPerMillion ?? self.cacheCreationPerMillion
                ?? self.inputPerMillion)
        let cached = Double(usage.cachedInputTokens ?? 0) * self.cachedInputPerMillion
        let output = Double((usage.outputTokens ?? 0) + (usage.reasoningTokens ?? 0))
            * self.outputPerMillion
        return (input + cacheCreation + cacheCreation1h + cached + output) / 1_000_000
    }
}

public struct PricingCatalogMetadata: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let catalogVersion: Int
    public let publishedAt: Date
    public let effectiveDate: String

    public init(
        schemaVersion: Int,
        catalogVersion: Int,
        publishedAt: Date,
        effectiveDate: String)
    {
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.publishedAt = publishedAt
        self.effectiveDate = effectiveDate
    }
}

public struct PricingCatalogManifest: Codable, Hashable, Sendable {
    public enum MatchKind: String, Codable, Hashable, Sendable {
        case exact
        case prefix
        case contains
    }

    public struct Model: Codable, Hashable, Sendable {
        public let id: String
        public let providerID: ProviderID
        public let matchKind: MatchKind
        public let modelPattern: String
        public let effectiveFrom: Date?
        public let effectiveUntil: Date?
        public let pricing: ModelTokenPricing
        public let sourceURL: URL

        public init(
            id: String,
            providerID: ProviderID,
            matchKind: MatchKind,
            modelPattern: String,
            effectiveFrom: Date? = nil,
            effectiveUntil: Date? = nil,
            pricing: ModelTokenPricing,
            sourceURL: URL)
        {
            self.id = id
            self.providerID = providerID
            self.matchKind = matchKind
            self.modelPattern = modelPattern
            self.effectiveFrom = effectiveFrom
            self.effectiveUntil = effectiveUntil
            self.pricing = pricing
            self.sourceURL = sourceURL
        }
    }

    public let schemaVersion: Int
    public let catalogVersion: Int
    public let publishedAt: Date
    public let effectiveDate: String
    public let models: [Model]

    public var metadata: PricingCatalogMetadata {
        PricingCatalogMetadata(
            schemaVersion: self.schemaVersion,
            catalogVersion: self.catalogVersion,
            publishedAt: self.publishedAt,
            effectiveDate: self.effectiveDate)
    }

    public init(
        schemaVersion: Int,
        catalogVersion: Int,
        publishedAt: Date,
        effectiveDate: String,
        models: [Model])
    {
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.publishedAt = publishedAt
        self.effectiveDate = effectiveDate
        self.models = models
    }
}

public enum PricingCatalogValidationError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidCatalogVersion
    case publishedInFuture
    case invalidEffectiveDate
    case noModels
    case duplicateModelID(String)
    case invalidProvider(String)
    case invalidPattern(String)
    case invalidEffectiveWindow(String)
    case overlappingEffectiveWindows(String)
    case invalidPricing(String)
    case untrustedSource(String)
    case downgrade(current: Int, candidate: Int)
    case versionConflict(Int)
}

public enum TokenPricingCatalog {
    private final class LockedState: @unchecked Sendable {
        private let lock = NSLock()
        private var storedManifest: PricingCatalogManifest

        init(manifest: PricingCatalogManifest) {
            self.storedManifest = manifest
        }

        func read<T>(_ body: (PricingCatalogManifest) throws -> T) rethrows -> T {
            self.lock.lock()
            defer { self.lock.unlock() }
            return try body(self.storedManifest)
        }

        func update<T>(_ body: (inout PricingCatalogManifest) throws -> T) rethrows -> T {
            self.lock.lock()
            defer { self.lock.unlock() }
            return try body(&self.storedManifest)
        }
    }

    private static let supportedSchemaVersion = 1
    private static let allowedProviders: Set<ProviderID> = [.codex, .claude]
    private static let allowedSourceHosts = Set([
        "developers.openai.com",
        "platform.openai.com",
        "platform.claude.com",
        "docs.anthropic.com",
    ])
    private static let maximumPricePerMillion = 10_000.0
    private static let state = LockedState(manifest: TokenPricingCatalog.loadBundledManifest())

    public static var metadata: PricingCatalogMetadata {
        self.state.read(\.metadata)
    }

    public static var manifest: PricingCatalogManifest {
        self.state.read { $0 }
    }

    public static func pricing(
        providerID: ProviderID,
        modelID: String,
        at date: Date = .now) -> ModelTokenPricing?
    {
        let modelID = modelID.lowercased()
        return self.state.read { manifest in
            let candidates = manifest.models.filter { entry in
                guard entry.providerID == providerID,
                      self.matches(modelID, entry: entry)
                else { return false }
                if let effectiveFrom = entry.effectiveFrom, date < effectiveFrom { return false }
                if let effectiveUntil = entry.effectiveUntil, date >= effectiveUntil { return false }
                return true
            }
            let sorted = candidates.sorted { lhs, rhs -> Bool in
                let lhsRank: Int = self.matchRank(lhs.matchKind)
                let rhsRank: Int = self.matchRank(rhs.matchKind)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
                let lhsLength: Int = lhs.modelPattern.count
                let rhsLength: Int = rhs.modelPattern.count
                return lhsLength > rhsLength
            }
            return sorted.first?.pricing
        }
    }

    public static func estimate(
        providerID: ProviderID,
        usage: TokenUsage,
        at date: Date = .now) -> TokenCostEstimate?
    {
        guard let modelID = usage.modelID,
              let pricing = self.pricing(providerID: providerID, modelID: modelID, at: date)
        else { return nil }
        return TokenCostEstimate(
            label: usage.label,
            amountUSD: pricing.estimate(usage),
            modelIDs: [modelID])
    }

    @discardableResult
    public static func activate(
        _ manifest: PricingCatalogManifest,
        at date: Date = .now) throws -> Bool
    {
        try self.validate(manifest, at: date)
        return try self.state.update { current in
            try self.validateUpdate(manifest, replacing: current)
            if manifest == current { return false }
            current = manifest
            return true
        }
    }

    public static func validateUpdate(
        _ candidate: PricingCatalogManifest,
        replacing current: PricingCatalogManifest) throws
    {
        guard candidate.catalogVersion >= current.catalogVersion else {
            throw PricingCatalogValidationError.downgrade(
                current: current.catalogVersion,
                candidate: candidate.catalogVersion)
        }
        if candidate.catalogVersion == current.catalogVersion {
            guard candidate == current else {
                throw PricingCatalogValidationError.versionConflict(candidate.catalogVersion)
            }
            return
        }
        guard candidate.publishedAt >= current.publishedAt else {
            throw PricingCatalogValidationError.downgrade(
                current: current.catalogVersion,
                candidate: candidate.catalogVersion)
        }
    }

    public static func decodeAndValidate(
        _ data: Data,
        at date: Date = .now) throws -> PricingCatalogManifest
    {
        guard data.count <= PricingCatalogUpdateClient.maximumManifestBytes else {
            throw PricingCatalogUpdateError.manifestTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(PricingCatalogManifest.self, from: data)
        try self.validate(manifest, at: date)
        return manifest
    }

    public static func validate(
        _ manifest: PricingCatalogManifest,
        at date: Date = .now) throws
    {
        guard manifest.schemaVersion == self.supportedSchemaVersion else {
            throw PricingCatalogValidationError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.catalogVersion > 0 else {
            throw PricingCatalogValidationError.invalidCatalogVersion
        }
        guard manifest.publishedAt <= date.addingTimeInterval(24 * 60 * 60) else {
            throw PricingCatalogValidationError.publishedInFuture
        }
        guard let effectiveDate = self.parseISODate(manifest.effectiveDate),
              effectiveDate <= date.addingTimeInterval(24 * 60 * 60)
        else {
            throw PricingCatalogValidationError.invalidEffectiveDate
        }
        guard !manifest.models.isEmpty else {
            throw PricingCatalogValidationError.noModels
        }

        var ids = Set<String>()
        var groups: [String: [PricingCatalogManifest.Model]] = [:]
        for model in manifest.models {
            guard ids.insert(model.id).inserted else {
                throw PricingCatalogValidationError.duplicateModelID(model.id)
            }
            guard self.allowedProviders.contains(model.providerID) else {
                throw PricingCatalogValidationError.invalidProvider(model.providerID.rawValue)
            }
            guard !model.id.isEmpty,
                  !model.modelPattern.isEmpty,
                  model.modelPattern == model.modelPattern.lowercased(),
                  model.modelPattern.count <= 128
            else {
                throw PricingCatalogValidationError.invalidPattern(model.id)
            }
            if let from = model.effectiveFrom,
               let until = model.effectiveUntil,
               from >= until
            {
                throw PricingCatalogValidationError.invalidEffectiveWindow(model.id)
            }
            guard self.isValid(model.pricing) else {
                throw PricingCatalogValidationError.invalidPricing(model.id)
            }
            guard model.sourceURL.scheme == "https",
                  let host = model.sourceURL.host?.lowercased(),
                  self.allowedSourceHosts.contains(host)
            else {
                throw PricingCatalogValidationError.untrustedSource(model.id)
            }
            let key = "\(model.providerID.rawValue)|\(model.matchKind.rawValue)|\(model.modelPattern)"
            groups[key, default: []].append(model)
        }

        for entries in groups.values where entries.count > 1 {
            let sorted = entries.sorted { ($0.effectiveFrom ?? .distantPast) < ($1.effectiveFrom ?? .distantPast) }
            for index in 1..<sorted.count {
                let previousEnd = sorted[index - 1].effectiveUntil ?? .distantFuture
                let currentStart = sorted[index].effectiveFrom ?? .distantPast
                guard previousEnd <= currentStart else {
                    throw PricingCatalogValidationError.overlappingEffectiveWindows(sorted[index].id)
                }
            }
        }
    }

    private static func loadBundledManifest() -> PricingCatalogManifest {
        if let url = self.bundledManifestURL(),
           let data = try? Data(contentsOf: url),
           let manifest = try? self.decodeAndValidate(data)
        {
            return manifest
        }
        return self.emergencyFallbackManifest
    }

    private static func bundledManifestURL() -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let packagedURL = resourceURL
                .appending(path: "TokeniBar_TokeniCore.bundle", directoryHint: .isDirectory)
                .appending(path: "Resources", directoryHint: .isDirectory)
                .appending(path: "token-pricing.json")
            if FileManager.default.fileExists(atPath: packagedURL.path) {
                return packagedURL
            }
        }

        // SwiftPM's generated accessor can fatalError when a manually packaged .app omits
        // its resource bundle. Packaged apps use the checked path above; development and
        // test binaries can safely use Bundle.module's build-directory fallback.
        guard Bundle.main.bundleURL.pathExtension.lowercased() != "app" else { return nil }
        return Bundle.module.url(forResource: "token-pricing", withExtension: "json")
    }

    private static var emergencyFallbackManifest: PricingCatalogManifest {
        let source = URL(string: "https://developers.openai.com/api/docs/models")!
        let claudeSource = URL(string: "https://platform.claude.com/docs/en/about-claude/pricing")!
        return PricingCatalogManifest(
            schemaVersion: 1,
            catalogVersion: 1,
            publishedAt: Date(timeIntervalSince1970: 1_768_435_200),
            effectiveDate: "2026-01-15",
            models: [
                .init(id: "emergency-gpt-5.6-sol", providerID: .codex, matchKind: .contains,
                      modelPattern: "gpt-5.6-sol",
                      pricing: .init(inputPerMillion: 5, cachedInputPerMillion: 0.5, outputPerMillion: 30),
                      sourceURL: source),
                .init(id: "emergency-gpt-5-codex", providerID: .codex, matchKind: .contains,
                      modelPattern: "gpt-5-codex",
                      pricing: .init(inputPerMillion: 1.25, cachedInputPerMillion: 0.125, outputPerMillion: 10),
                      sourceURL: source),
                .init(id: "emergency-claude-opus-4", providerID: .claude, matchKind: .contains,
                      modelPattern: "opus-4",
                      pricing: .init(inputPerMillion: 5, cacheCreationPerMillion: 6.25,
                                     cacheCreation1hPerMillion: 10, cachedInputPerMillion: 0.5,
                                     outputPerMillion: 25), sourceURL: claudeSource),
                .init(id: "emergency-claude-sonnet-4", providerID: .claude, matchKind: .contains,
                      modelPattern: "sonnet-4",
                      pricing: .init(inputPerMillion: 3, cacheCreationPerMillion: 3.75,
                                     cacheCreation1hPerMillion: 6, cachedInputPerMillion: 0.3,
                                     outputPerMillion: 15), sourceURL: claudeSource),
                .init(id: "emergency-claude-haiku-4", providerID: .claude, matchKind: .contains,
                      modelPattern: "haiku-4",
                      pricing: .init(inputPerMillion: 1, cacheCreationPerMillion: 1.25,
                                     cacheCreation1hPerMillion: 2, cachedInputPerMillion: 0.1,
                                     outputPerMillion: 5), sourceURL: claudeSource),
            ])
    }

    private static func matches(_ modelID: String, entry: PricingCatalogManifest.Model) -> Bool {
        switch entry.matchKind {
        case .exact: modelID == entry.modelPattern
        case .prefix: modelID.hasPrefix(entry.modelPattern)
        case .contains: modelID.contains(entry.modelPattern)
        }
    }

    private static func matchRank(_ kind: PricingCatalogManifest.MatchKind) -> Int {
        switch kind {
        case .exact: 3
        case .prefix: 2
        case .contains: 1
        }
    }

    private static func isValid(_ pricing: ModelTokenPricing) -> Bool {
        let values = [
            pricing.inputPerMillion,
            pricing.cacheCreationPerMillion,
            pricing.cacheCreation1hPerMillion,
            pricing.cachedInputPerMillion,
            pricing.outputPerMillion,
        ].compactMap(\.self)
        return values.allSatisfy {
            $0.isFinite && $0 >= 0 && $0 <= self.maximumPricePerMillion
        }
    }

    private static func parseISODate(_ value: String) -> Date? {
        guard value.count == 10,
              value[value.index(value.startIndex, offsetBy: 4)] == "-",
              value[value.index(value.startIndex, offsetBy: 7)] == "-",
              value.enumerated().allSatisfy({ index, character in
                  index == 4 || index == 7 ? character == "-" : character.isNumber
              })
        else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value)
    }
}
