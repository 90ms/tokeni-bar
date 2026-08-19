import Foundation

struct CodexCLIRateLimitsResponse: Decodable, Sendable {
    let rateLimits: RateLimitSnapshot?
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCredits?

    enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsByLimitId
        case rateLimitResetCredits
    }

    struct RateLimitSnapshot: Decodable, Sendable {
        let limitId: String?
        let limitName: String?
        let planType: String?
        let primary: RateLimitWindow?
        let secondary: RateLimitWindow?
        let credits: Credits?

        enum CodingKeys: String, CodingKey {
            case limitId
            case limitName
            case planType
            case primary
            case secondary
            case credits
        }
    }

    struct RateLimitWindow: Decodable, Sendable {
        let usedPercent: Double
        let resetsAt: TimeInterval?
        let windowDurationMins: Int?

        enum CodingKeys: String, CodingKey {
            case usedPercent
            case resetsAt
            case windowDurationMins
        }
    }

    struct Credits: Decodable, Sendable {
        let balance: String?
        let hasCredits: Bool
        let unlimited: Bool

        enum CodingKeys: String, CodingKey {
            case balance
            case hasCredits
            case unlimited
        }

        init(hasCredits: Bool, unlimited: Bool, balance: String?) {
            self.balance = balance
            self.hasCredits = hasCredits
            self.unlimited = unlimited
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hasCredits = try container.decodeIfPresent(Bool.self, forKey: .hasCredits) ?? false
            self.unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited) ?? false
            if let value = try? container.decodeIfPresent(String.self, forKey: .balance) {
                self.balance = value
            } else if let value = try? container.decodeIfPresent(Double.self, forKey: .balance) {
                self.balance = String(value)
            } else {
                self.balance = nil
            }
        }
    }

    struct RateLimitResetCredits: Decodable, Sendable {
        let availableCount: Int
        let credits: [Credit]?

        struct Credit: Decodable, Sendable {
            let id: String
            let status: String
            let title: String?
            let description: String?
            let expiresAt: TimeInterval?

            enum CodingKeys: String, CodingKey {
                case id
                case status
                case title
                case description
                case expiresAt
            }
        }
    }

    func accountUsageResponse() -> CodexAccountUsageResponse? {
        let selected: (id: String?, snapshot: RateLimitSnapshot)?
        if let codex = self.rateLimitsByLimitId?["codex"] {
            selected = (id: "codex", snapshot: codex)
        } else if let rateLimits {
            selected = (id: rateLimits.limitId, snapshot: rateLimits)
        } else if let first = self.rateLimitsByLimitId?.sorted(by: { $0.key < $1.key }).first {
            selected = (id: first.key, snapshot: first.value)
        } else {
            selected = nil
        }
        guard let selected else { return nil }

        let additional = (self.rateLimitsByLimitId ?? [:])
            .sorted { $0.key < $1.key }
            .compactMap { id, snapshot -> CodexAccountUsageResponse.AdditionalRateLimit? in
                guard id != selected.id else { return nil }
                return CodexAccountUsageResponse.AdditionalRateLimit(
                    limitName: snapshot.limitName ?? id,
                    meteredFeature: id,
                    rateLimit: snapshot.rateLimit())
            }

        return CodexAccountUsageResponse(
            planType: selected.snapshot.planType,
            rateLimit: selected.snapshot.rateLimit(),
            credits: selected.snapshot.credits.map {
                CodexAccountUsageResponse.Credits(
                    hasCredits: $0.hasCredits,
                    unlimited: $0.unlimited,
                    balance: $0.balance)
            },
            additionalRateLimits: additional.isEmpty ? nil : additional)
    }

    func quotaResetCreditsSummary() -> QuotaResetCreditSummary? {
        guard let resetCredits = self.rateLimitResetCredits else { return nil }
        let credits = (resetCredits.credits ?? []).map { credit in
            QuotaResetCredit(
                id: credit.id,
                status: credit.status,
                title: credit.title ?? credit.description ?? "Limit reset",
                expiresAt: credit.expiresAt.map(Date.init(timeIntervalSince1970:)))
        }
        return QuotaResetCreditSummary(
            availableCount: resetCredits.availableCount,
            totalEarnedCount: 0,
            credits: credits)
    }
}

private extension CodexCLIRateLimitsResponse.RateLimitSnapshot {
    func rateLimit() -> CodexAccountUsageResponse.RateLimit? {
        guard self.primary != nil || self.secondary != nil else { return nil }
        return CodexAccountUsageResponse.RateLimit(
            primaryWindow: self.primary?.accountWindow(),
            secondaryWindow: self.secondary?.accountWindow())
    }
}

private extension CodexCLIRateLimitsResponse.RateLimitWindow {
    func accountWindow() -> CodexAccountUsageResponse.Window {
        CodexAccountUsageResponse.Window(
            usedPercent: self.usedPercent,
            resetAt: self.resetsAt,
            limitWindowSeconds: self.windowDurationMins.map { $0 * 60 })
    }
}
