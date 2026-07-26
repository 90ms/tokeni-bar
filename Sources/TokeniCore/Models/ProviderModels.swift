import Foundation

public struct ProviderID: RawRepresentable, Codable, Hashable, Sendable, Identifiable,
    ExpressibleByStringLiteral
{
    public let rawValue: String
    public var id: String { self.rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let codex: Self = "codex"
    public static let claude: Self = "claude"
    public static let grok: Self = "grok"
    public static let gemini: Self = "gemini"
    public static let openCode: Self = "opencode"
}

public struct ProviderCapabilities: Hashable, Sendable {
    public let supportsQuotaWindows: Bool
    public let supportsTokenUsage: Bool
    public let supportsCredits: Bool
    public let supportsAccountIdentity: Bool

    public init(
        supportsQuotaWindows: Bool = false,
        supportsTokenUsage: Bool = false,
        supportsCredits: Bool = false,
        supportsAccountIdentity: Bool = false)
    {
        self.supportsQuotaWindows = supportsQuotaWindows
        self.supportsTokenUsage = supportsTokenUsage
        self.supportsCredits = supportsCredits
        self.supportsAccountIdentity = supportsAccountIdentity
    }
}

public struct ProviderDescriptor: Identifiable, Hashable, Sendable {
    public let id: ProviderID
    public let displayName: String
    public let shortName: String
    public let systemImage: String
    public let iconAssetName: String?
    public let capabilities: ProviderCapabilities

    public init(
        id: ProviderID,
        displayName: String,
        shortName: String,
        systemImage: String,
        iconAssetName: String? = nil,
        capabilities: ProviderCapabilities)
    {
        self.id = id
        self.displayName = displayName
        self.shortName = shortName
        self.systemImage = systemImage
        self.iconAssetName = iconAssetName
        self.capabilities = capabilities
    }
}

public enum ProviderAvailability: String, Codable, Hashable, Sendable {
    case loading
    case available
    case stale
    case unavailable
    case failed
}

public enum UsageDataSource: String, Codable, Hashable, Sendable {
    case localSessionLog
    case localProtocol
    case officialAPI
    case estimated

    public var displayName: String {
        switch self {
        case .localSessionLog: "Local session"
        case .localProtocol: "Local protocol"
        case .officialAPI: "Account API"
        case .estimated: "Estimated"
        }
    }
}

public enum QuotaWindowKind: String, Codable, Hashable, Sendable {
    case session
    case weekly
    case monthly
    case context
    case custom
}

public struct QuotaWindow: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let kind: QuotaWindowKind
    public let label: String
    public let usedPercent: Double
    public let resetsAt: Date?
    public let durationMinutes: Int?

    public var remainingPercent: Double {
        100 - self.usedPercent
    }

    public init(
        id: String,
        kind: QuotaWindowKind,
        label: String,
        usedPercent: Double,
        resetsAt: Date? = nil,
        durationMinutes: Int? = nil)
    {
        self.id = id
        self.kind = kind
        self.label = label
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
        self.durationMinutes = durationMinutes
    }
}

public struct TokenUsage: Codable, Hashable, Sendable {
    public let label: String
    public let modelID: String?
    public let inputTokens: Int64?
    public let cacheCreationInputTokens: Int64?
    public let cacheCreation1hInputTokens: Int64?
    public let cachedInputTokens: Int64?
    public let outputTokens: Int64?
    public let reasoningTokens: Int64?
    public let totalTokens: Int64

    public init(
        label: String,
        modelID: String? = nil,
        inputTokens: Int64? = nil,
        cacheCreationInputTokens: Int64? = nil,
        cacheCreation1hInputTokens: Int64? = nil,
        cachedInputTokens: Int64? = nil,
        outputTokens: Int64? = nil,
        reasoningTokens: Int64? = nil,
        totalTokens: Int64)
    {
        self.label = label
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheCreation1hInputTokens = cacheCreation1hInputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
    }
}

public struct TokenCostEstimate: Hashable, Sendable {
    public let label: String
    public let amountUSD: Double
    public let modelIDs: [String]

    public init(label: String, amountUSD: Double, modelIDs: [String]) {
        self.label = label
        self.amountUSD = amountUSD
        self.modelIDs = modelIDs
    }
}

public struct CreditBalance: Codable, Hashable, Sendable {
    public let balance: String?
    public let hasCredits: Bool
    public let unlimited: Bool

    public init(balance: String?, hasCredits: Bool, unlimited: Bool) {
        self.balance = balance
        self.hasCredits = hasCredits
        self.unlimited = unlimited
    }
}

public struct QuotaResetCredit: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let status: String
    public let title: String
    public let expiresAt: Date?

    public init(id: String, status: String, title: String, expiresAt: Date?) {
        self.id = id
        self.status = status
        self.title = title
        self.expiresAt = expiresAt
    }
}

public struct QuotaResetCreditSummary: Codable, Hashable, Sendable {
    public let availableCount: Int
    public let totalEarnedCount: Int
    public let credits: [QuotaResetCredit]

    public init(availableCount: Int, totalEarnedCount: Int, credits: [QuotaResetCredit]) {
        self.availableCount = max(availableCount, 0)
        self.totalEarnedCount = max(totalEarnedCount, 0)
        self.credits = credits
    }
}

public struct ProviderSnapshot: Identifiable, Hashable, Sendable {
    public let descriptor: ProviderDescriptor
    public let availability: ProviderAvailability
    public let source: UsageDataSource?
    public let quotaWindows: [QuotaWindow]
    public let tokenUsage: TokenUsage?
    public let costEstimate: TokenCostEstimate?
    public let accountTokenUsage: AccountTokenUsageSummary?
    public let credits: CreditBalance?
    public let quotaResetCredits: QuotaResetCreditSummary?
    public let detail: String?
    public let updatedAt: Date

    public var id: ProviderID { self.descriptor.id }

    public init(
        descriptor: ProviderDescriptor,
        availability: ProviderAvailability,
        source: UsageDataSource?,
        quotaWindows: [QuotaWindow] = [],
        tokenUsage: TokenUsage? = nil,
        costEstimate: TokenCostEstimate? = nil,
        accountTokenUsage: AccountTokenUsageSummary? = nil,
        credits: CreditBalance? = nil,
        quotaResetCredits: QuotaResetCreditSummary? = nil,
        detail: String? = nil,
        updatedAt: Date = .now)
    {
        self.descriptor = descriptor
        self.availability = availability
        self.source = source
        self.quotaWindows = quotaWindows
        self.tokenUsage = tokenUsage
        self.costEstimate = costEstimate
        self.accountTokenUsage = accountTokenUsage
        self.credits = credits
        self.quotaResetCredits = quotaResetCredits
        self.detail = detail
        self.updatedAt = updatedAt
    }

    public static func loading(_ descriptor: ProviderDescriptor) -> Self {
        .init(
            descriptor: descriptor,
            availability: .loading,
            source: nil,
            detail: "Refreshing usage…")
    }
}
