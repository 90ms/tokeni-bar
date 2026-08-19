import Foundation

struct CodexResetCreditsResponse: Decodable, Sendable {
    let availableCount: Int
    let totalEarnedCount: Int
    let credits: [Credit]

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case totalEarnedCount = "total_earned_count"
        case credits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount) ?? 0
        self.totalEarnedCount = try container.decodeIfPresent(Int.self, forKey: .totalEarnedCount) ?? 0
        self.credits = try container.decodeIfPresent([Credit].self, forKey: .credits) ?? []
    }

    struct Credit: Decodable, Sendable {
        let status: String
        let title: String
        let expiresAt: Date?

        enum CodingKeys: String, CodingKey {
            case status, title
            case expiresAt = "expires_at"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
            self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Limit reset"
            if let value = try? container.decodeIfPresent(String.self, forKey: .expiresAt) {
                self.expiresAt = TimestampParser.parse(value)
            } else if let value = try? container.decodeIfPresent(Double.self, forKey: .expiresAt) {
                let seconds = value > 10_000_000_000 ? value / 1000 : value
                self.expiresAt = Date(timeIntervalSince1970: seconds)
            } else {
                self.expiresAt = nil
            }
        }
    }

    func summary() -> QuotaResetCreditSummary {
        QuotaResetCreditSummary(
            availableCount: self.availableCount,
            totalEarnedCount: self.totalEarnedCount,
            credits: self.credits.enumerated().map { index, credit in
                QuotaResetCredit(
                    id: "\(index)-\(credit.status)-\(credit.title)-\(credit.expiresAt?.timeIntervalSince1970 ?? 0)",
                    status: credit.status,
                    title: credit.title,
                    expiresAt: credit.expiresAt)
            })
    }
}
