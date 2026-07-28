import Foundation

struct CodexAccountCredentials: Sendable {
    let accessToken: String
    let accountID: String?

    static func decode(_ data: Data) throws -> Self {
        let root = try JSONDecoder().decode(Root.self, from: data)
        guard let accessToken = root.tokens?.accessToken?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !accessToken.isEmpty
        else { throw CodexAccountUsageError.invalidCredentials }

        let accountID = root.tokens?.accountID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(
            accessToken: accessToken,
            accountID: accountID?.isEmpty == false ? accountID : nil)
    }

    private struct Root: Decodable {
        let tokens: Tokens?
    }

    private struct Tokens: Decodable {
        let accessToken: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accessTokenCamel = "accessToken"
            case accountID = "account_id"
            case accountIDCamel = "accountId"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
                ?? container.decodeIfPresent(String.self, forKey: .accessTokenCamel)
            self.accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
                ?? container.decodeIfPresent(String.self, forKey: .accountIDCamel)
        }
    }
}

struct CodexAccountCredentialLoader: Sendable {
    private let credentialsFile: URL

    init(homeDirectory: URL) {
        self.credentialsFile = homeDirectory.appending(path: ".codex/auth.json")
    }

    func load() throws -> CodexAccountCredentials {
        guard let data = LocalFiles.data(
            in: self.credentialsFile,
            maximumBytes: 1 * 1_024 * 1_024)
        else {
            throw CodexAccountUsageError.credentialsUnavailable
        }
        return try CodexAccountCredentials.decode(data)
    }
}

enum CodexAccountUsageError: LocalizedError, Sendable {
    case credentialsUnavailable
    case invalidCredentials
    case unauthorized
    case rateLimited
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .credentialsUnavailable:
            "Codex account credentials are unavailable. Run Codex once to sign in."
        case .invalidCredentials:
            "Codex account credentials have an unsupported format."
        case .unauthorized:
            "Codex sign-in expired. Run Codex once to sign in again."
        case .rateLimited:
            "Codex usage is temporarily rate limited."
        case let .server(status):
            "Codex usage request failed with HTTP \(status)."
        case .invalidResponse:
            "Codex usage response was invalid."
        }
    }
}

struct CodexAccountUsageResponse: Decodable, Sendable {
    let planType: String?
    let rateLimit: RateLimit?
    let credits: Credits?
    let additionalRateLimits: [AdditionalRateLimit]?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
        case additionalRateLimits = "additional_rate_limits"
    }

    struct RateLimit: Decodable, Sendable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct Window: Decodable, Sendable {
        let usedPercent: Double
        let resetAt: TimeInterval?
        let limitWindowSeconds: Int?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
        }
    }

    struct AdditionalRateLimit: Decodable, Sendable {
        let limitName: String?
        let meteredFeature: String?
        let rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case limitName = "limit_name"
            case meteredFeature = "metered_feature"
            case rateLimit = "rate_limit"
        }
    }

    struct Credits: Decodable, Sendable {
        let hasCredits: Bool
        let unlimited: Bool
        let balance: String?

        enum CodingKeys: String, CodingKey {
            case hasCredits = "has_credits"
            case unlimited
            case balance
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

    func quotaWindows() -> [QuotaWindow] {
        var windows: [QuotaWindow] = []
        if let primary = self.rateLimit?.primaryWindow {
            windows.append(primary.quotaWindow(id: "primary", fallbackLabel: "Primary"))
        }
        if let secondary = self.rateLimit?.secondaryWindow {
            windows.append(secondary.quotaWindow(id: "secondary", fallbackLabel: "Secondary"))
        }

        for (index, additional) in (self.additionalRateLimits ?? []).enumerated() {
            let name = additional.limitName?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? additional.meteredFeature?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Additional limit"
            if let primary = additional.rateLimit?.primaryWindow {
                windows.append(primary.quotaWindow(
                    id: "additional-\(index)-primary",
                    fallbackLabel: name,
                    prefix: name))
            }
            if let secondary = additional.rateLimit?.secondaryWindow {
                windows.append(secondary.quotaWindow(
                    id: "additional-\(index)-secondary",
                    fallbackLabel: name,
                    prefix: name))
            }
        }
        return windows
    }

    var creditBalance: CreditBalance? {
        self.credits.map {
            CreditBalance(balance: $0.balance, hasCredits: $0.hasCredits, unlimited: $0.unlimited)
        }
    }
}

private extension CodexAccountUsageResponse.Window {
    func quotaWindow(id: String, fallbackLabel: String, prefix: String? = nil) -> QuotaWindow {
        let durationMinutes = self.limitWindowSeconds.map { $0 / 60 }
        let role: (kind: QuotaWindowKind, label: String)
        switch durationMinutes {
        case let minutes? where minutes >= 7 * 24 * 60:
            role = (.weekly, "Weekly")
        case let minutes? where minutes >= 4 * 60 && minutes <= 6 * 60:
            role = (.session, "5-hour")
        case let minutes? where minutes < 24 * 60:
            role = (.session, fallbackLabel)
        default:
            role = (.custom, fallbackLabel)
        }
        let label = prefix.map { "\($0) \(role.label.lowercased())" } ?? role.label
        return QuotaWindow(
            id: id,
            kind: role.kind,
            label: label,
            usedPercent: self.usedPercent,
            resetsAt: self.resetAt.map(Date.init(timeIntervalSince1970:)),
            durationMinutes: durationMinutes)
    }
}

struct CodexAccountUsageResult: Sendable {
    let response: CodexAccountUsageResponse
    let fetchedAt: Date
}

actor CodexAccountUsageCache {
    static let shared = CodexAccountUsageCache()

    private var response: CodexAccountUsageResponse?
    private var accountID: String?
    private var fetchedAt: Date?

    func value(
        accountID: String?,
        maxAge: TimeInterval,
        now: Date = .now) -> CodexAccountUsageResult?
    {
        guard self.accountID == accountID,
              let response,
              let fetchedAt,
              now.timeIntervalSince(fetchedAt) < maxAge,
              !response.hasElapsedReset(at: now)
        else { return nil }
        return CodexAccountUsageResult(response: response, fetchedAt: fetchedAt)
    }

    func store(_ response: CodexAccountUsageResponse, accountID: String?, fetchedAt: Date) {
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

struct CodexAccountUsageClient: Sendable {
    private let session: URLSession
    private let cache: CodexAccountUsageCache

    init(session: URLSession = .shared, cache: CodexAccountUsageCache = .shared) {
        self.session = session
        self.cache = cache
    }

    func fetch(credentials: CodexAccountCredentials) async throws -> CodexAccountUsageResult {
        if let cached = await cache.value(accountID: credentials.accountID, maxAge: 60) {
            return cached
        }
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            throw CodexAccountUsageError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("tokeni-bar/0.2.0", forHTTPHeaderField: "User-Agent")
        if let accountID = credentials.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexAccountUsageError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            guard let usage = try? JSONDecoder().decode(CodexAccountUsageResponse.self, from: data) else {
                throw CodexAccountUsageError.invalidResponse
            }
            let fetchedAt = Date.now
            await self.cache.store(usage, accountID: credentials.accountID, fetchedAt: fetchedAt)
            return CodexAccountUsageResult(response: usage, fetchedAt: fetchedAt)
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

private extension CodexAccountUsageResponse {
    func hasElapsedReset(at date: Date) -> Bool {
        let standardWindows = [
            self.rateLimit?.primaryWindow,
            self.rateLimit?.secondaryWindow,
        ]
        let additionalWindows = (self.additionalRateLimits ?? []).flatMap {
            [$0.rateLimit?.primaryWindow, $0.rateLimit?.secondaryWindow]
        }
        return (standardWindows + additionalWindows)
            .compactMap { $0?.resetAt }
            .contains { Date(timeIntervalSince1970: $0) <= date }
    }
}
