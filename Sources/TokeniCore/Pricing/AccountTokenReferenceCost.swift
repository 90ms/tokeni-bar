import Foundation

/// Versioned assumptions used to translate an undifferentiated total-token count
/// into an API-equivalent reference amount. This is not an API bill.
public struct AccountTokenReferenceCostAssumption: Hashable, Sendable {
    public let profileID: String
    public let profileVersion: Int
    public let pricingCatalogVersion: Int
    public let referenceModelID: String
    public let inputTokenShare: Double
    public let outputTokenShare: Double
    public let cachedInputTokenShare: Double
    public let usdPerMillionTokens: Double

    init(
        profileID: String,
        profileVersion: Int,
        pricingCatalogVersion: Int,
        referenceModelID: String,
        inputTokenShare: Double,
        outputTokenShare: Double,
        cachedInputTokenShare: Double,
        pricing: ModelTokenPricing)
    {
        self.profileID = profileID
        self.profileVersion = profileVersion
        self.pricingCatalogVersion = pricingCatalogVersion
        self.referenceModelID = referenceModelID
        self.inputTokenShare = inputTokenShare
        self.outputTokenShare = outputTokenShare
        self.cachedInputTokenShare = cachedInputTokenShare
        self.usdPerMillionTokens = inputTokenShare * pricing.inputPerMillion
            + outputTokenShare * pricing.outputPerMillion
            + cachedInputTokenShare * pricing.cachedInputPerMillion
    }
}

public struct AccountTokenReferenceCost: Hashable, Sendable {
    public let tokenCount: Int64
    public let amountUSD: Double
    public let assumption: AccountTokenReferenceCostAssumption

    /// Always true because account totals do not identify model, input/output,
    /// cached-input, or reasoning-token proportions.
    public var isApproximate: Bool { true }

    /// Stable identifier that a UI can map to localized explanatory text.
    public var disclosureID: String { "api-equivalent-reference-not-actual-charge" }
}

public struct AccountTokenPeriodReferenceCosts: Hashable, Sendable {
    public let today: AccountTokenReferenceCost?
    public let currentMonth: AccountTokenReferenceCost
    public let lifetime: AccountTokenReferenceCost
}

public struct AccountTokenReferenceCostEstimator: Hashable, Sendable {
    public let assumption: AccountTokenReferenceCostAssumption

    private init(assumption: AccountTokenReferenceCostAssumption) {
        self.assumption = assumption
    }

    /// Creates a Codex reference profile from the active, validated
    /// pricing catalog. Version 1 assumes 80% uncached input and 20% output for
    /// `gpt-5-codex`; it does not claim that an account actually used this mix.
    public static func codexInputOutputReferenceV1(at date: Date = .now) -> Self? {
        let modelID = "gpt-5-codex"
        guard let pricing = TokenPricingCatalog.pricing(
            providerID: .codex,
            modelID: modelID,
            at: date)
        else { return nil }
        return Self(assumption: AccountTokenReferenceCostAssumption(
            profileID: "codex-reference-80-input-20-output-v1",
            profileVersion: 1,
            pricingCatalogVersion: TokenPricingCatalog.metadata.catalogVersion,
            referenceModelID: modelID,
            inputTokenShare: 0.8,
            outputTokenShare: 0.2,
            cachedInputTokenShare: 0,
            pricing: pricing))
    }

    public func estimate(tokenCount: Int64) -> AccountTokenReferenceCost {
        let normalizedTokenCount = max(tokenCount, 0)
        let amountUSD = Double(normalizedTokenCount)
            * self.assumption.usdPerMillionTokens / 1_000_000
        return AccountTokenReferenceCost(
            tokenCount: normalizedTokenCount,
            amountUSD: amountUSD.isFinite ? amountUSD : .greatestFiniteMagnitude,
            assumption: self.assumption)
    }

    public func estimate(
        summary: AccountTokenUsageSummary) -> AccountTokenPeriodReferenceCosts
    {
        AccountTokenPeriodReferenceCosts(
            today: summary.todayTokens.map(self.estimate(tokenCount:)),
            currentMonth: self.estimate(tokenCount: summary.currentMonthTokens),
            lifetime: self.estimate(tokenCount: summary.lifetimeTokens))
    }
}
