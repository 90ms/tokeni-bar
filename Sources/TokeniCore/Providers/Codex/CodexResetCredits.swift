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

struct CodexResetCreditsResult: Sendable {
    let response: CodexResetCreditsResponse
    let fetchedAt: Date
}

actor CodexResetCreditsCache {
    static let shared = CodexResetCreditsCache()

    private var response: CodexResetCreditsResponse?
    private var accountID: String?
    private var fetchedAt: Date?

    func value(accountID: String?, maxAge: TimeInterval) -> CodexResetCreditsResult? {
        guard self.accountID == accountID,
              let response,
              let fetchedAt,
              Date.now.timeIntervalSince(fetchedAt) < maxAge
        else { return nil }
        return CodexResetCreditsResult(response: response, fetchedAt: fetchedAt)
    }

    func store(_ response: CodexResetCreditsResponse, accountID: String?, fetchedAt: Date) {
        self.response = response
        self.accountID = accountID
        self.fetchedAt = fetchedAt
    }

    func invalidate() {
        self.response = nil
        self.accountID = nil
        self.fetchedAt = nil
    }
}

struct CodexResetCreditsClient: Sendable {
    private let session: URLSession
    private let cache: CodexResetCreditsCache

    init(session: URLSession = .shared, cache: CodexResetCreditsCache = .shared) {
        self.session = session
        self.cache = cache
    }

    func fetch(credentials: CodexAccountCredentials) async throws -> CodexResetCreditsResult {
        if let cached = await self.cache.value(accountID: credentials.accountID, maxAge: 5 * 60) {
            return cached
        }
        guard let url = URL(
            string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")
        else { throw CodexAccountUsageError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("tokeni-bar/0.5.0", forHTTPHeaderField: "User-Agent")
        if let accountID = credentials.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexAccountUsageError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            guard let credits = try? JSONDecoder().decode(CodexResetCreditsResponse.self, from: data)
            else { throw CodexAccountUsageError.invalidResponse }
            let fetchedAt = Date.now
            await self.cache.store(credits, accountID: credentials.accountID, fetchedAt: fetchedAt)
            return CodexResetCreditsResult(response: credits, fetchedAt: fetchedAt)
        case 401, 403:
            throw CodexAccountUsageError.unauthorized
        case 429:
            throw CodexAccountUsageError.rateLimited
        default:
            throw CodexAccountUsageError.server(http.statusCode)
        }
    }

    func invalidateCache() async {
        await self.cache.invalidate()
    }
}
