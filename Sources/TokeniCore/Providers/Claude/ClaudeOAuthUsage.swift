import Foundation
import LocalAuthentication
import Security

struct ClaudeOAuthCredentials: Sendable {
    let accessToken: String
    let expiresAt: Date?
    let rateLimitTier: String?
    let subscriptionType: String?

    var isExpired: Bool {
        self.isExpired(at: .now)
    }

    func isExpired(at date: Date) -> Bool {
        guard let expiresAt else { return false }
        return date >= expiresAt
    }

    static func decode(_ data: Data) throws -> Self {
        let root = try JSONDecoder().decode(Root.self, from: data)
        guard let oauth = root.claudeAiOauth,
              let accessToken = oauth.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accessToken.isEmpty
        else { throw ClaudeOAuthUsageError.invalidCredentials }

        return Self(
            accessToken: accessToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            rateLimitTier: oauth.rateLimitTier,
            subscriptionType: oauth.subscriptionType)
    }

    private struct Root: Decodable {
        let claudeAiOauth: OAuth?
    }

    private struct OAuth: Decodable {
        let accessToken: String?
        let expiresAt: Double?
        let rateLimitTier: String?
        let subscriptionType: String?
    }
}

struct ClaudeOAuthCredentialLoader: Sendable {
    private let credentialsFile: URL
    private let allowKeychain: Bool

    init(homeDirectory: URL, allowKeychain: Bool = true) {
        self.credentialsFile = homeDirectory.appending(path: ".claude/.credentials.json")
        self.allowKeychain = allowKeychain
    }

    func load(interactive: Bool = false) throws -> ClaudeOAuthCredentials {
        if let data = try? Data(contentsOf: self.credentialsFile),
           let credentials = try? ClaudeOAuthCredentials.decode(data)
        {
            guard !credentials.isExpired else { throw ClaudeOAuthUsageError.expiredCredentials }
            return credentials
        }
        guard self.allowKeychain else {
            throw ClaudeOAuthUsageError.credentialsUnavailable(errSecItemNotFound)
        }

        let query = Self.keychainQuery(interactive: interactive)
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecInteractionNotAllowed {
            throw ClaudeOAuthUsageError.authorizationRequired
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw ClaudeOAuthUsageError.credentialsUnavailable(status)
        }
        let credentials = try ClaudeOAuthCredentials.decode(data)
        guard !credentials.isExpired else { throw ClaudeOAuthUsageError.expiredCredentials }
        return credentials
    }

    static func keychainQuery(interactive: Bool) -> [CFString: Any] {
        let context = LAContext()
        context.interactionNotAllowed = !interactive
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
            kSecUseAuthenticationContext: context,
        ]
    }
}

enum ClaudeOAuthUsageError: LocalizedError, Sendable {
    case authorizationRequired
    case credentialsUnavailable(OSStatus)
    case invalidCredentials
    case expiredCredentials
    case unauthorized
    case rateLimited
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .authorizationRequired:
            "Claude Keychain access requires approval. Connect Claude in Settings."
        case .credentialsUnavailable:
            "Claude OAuth credentials are unavailable. Connect Claude in Settings."
        case .invalidCredentials:
            "Claude OAuth credentials have an unsupported format."
        case .expiredCredentials:
            "Claude OAuth session expired. Open Claude Code once, then refresh."
        case .unauthorized:
            "Claude OAuth session is unauthorized. Run Claude Code to sign in again."
        case .rateLimited:
            "Claude usage is temporarily rate limited."
        case let .server(status):
            "Claude usage request failed with HTTP \(status)."
        case .invalidResponse:
            "Claude usage response was invalid."
        }
    }
}

actor ClaudeOAuthCredentialCache {
    private var credentials: ClaudeOAuthCredentials?

    func value(at date: Date = .now) -> ClaudeOAuthCredentials? {
        guard let credentials, !credentials.isExpired(at: date) else {
            self.credentials = nil
            return nil
        }
        return credentials
    }

    func store(_ credentials: ClaudeOAuthCredentials) {
        self.credentials = credentials
    }

    func invalidate() {
        self.credentials = nil
    }
}

struct ClaudeOAuthUsageResponse: Decodable, Sendable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let limits: [Limit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case limits
    }

    struct UsageWindow: Decodable, Sendable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    struct Limit: Decodable, Sendable {
        let kind: String?
        let group: String?
        let percent: Double?
        let resetsAt: String?
        let scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind, group, percent, scope
            case resetsAt = "resets_at"
        }
    }

    struct Scope: Decodable, Sendable {
        let model: Model?
    }

    struct Model: Decodable, Sendable {
        let id: String?
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    func quotaWindows() -> [QuotaWindow] {
        var windows: [QuotaWindow] = []
        if let window = self.fiveHour?.quotaWindow(
            id: "five-hour",
            kind: .session,
            label: "5-hour",
            durationMinutes: 5 * 60)
        {
            windows.append(window)
        }
        if let window = self.sevenDay?.quotaWindow(
            id: "seven-day",
            kind: .weekly,
            label: "Weekly",
            durationMinutes: 7 * 24 * 60)
        {
            windows.append(window)
        }

        let legacyModelWindows: [(String, String, UsageWindow?)] = [
            ("seven-day-sonnet", "Sonnet weekly", self.sevenDaySonnet),
            ("seven-day-opus", "Opus weekly", self.sevenDayOpus),
        ]
        for (id, label, value) in legacyModelWindows {
            if let window = value?.quotaWindow(
                id: id,
                kind: .weekly,
                label: label,
                durationMinutes: 7 * 24 * 60)
            {
                windows.append(window)
            }
        }

        var seenLabels = Set(windows.map(\.label))
        for (index, limit) in (self.limits ?? []).enumerated() {
            guard limit.kind == "weekly_scoped" || limit.group == "weekly" && limit.scope?.model != nil,
                  let percent = limit.percent,
                  let modelName = limit.scope?.model?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !modelName.isEmpty
            else { continue }
            let label = "\(modelName) weekly"
            guard seenLabels.insert(label).inserted else { continue }
            windows.append(QuotaWindow(
                id: "scoped-weekly-\(limit.scope?.model?.id ?? String(index))",
                kind: .weekly,
                label: label,
                usedPercent: percent,
                resetsAt: TimestampParser.parse(limit.resetsAt),
                durationMinutes: 7 * 24 * 60))
        }
        return windows
    }
}

private extension ClaudeOAuthUsageResponse.UsageWindow {
    func quotaWindow(
        id: String,
        kind: QuotaWindowKind,
        label: String,
        durationMinutes: Int) -> QuotaWindow?
    {
        guard let utilization else { return nil }
        return QuotaWindow(
            id: id,
            kind: kind,
            label: label,
            usedPercent: utilization,
            resetsAt: TimestampParser.parse(self.resetsAt),
            durationMinutes: durationMinutes)
    }
}

struct ClaudeOAuthUsageResult: Sendable {
    let response: ClaudeOAuthUsageResponse
    let fetchedAt: Date
}

actor ClaudeOAuthUsageCache {
    static let shared = ClaudeOAuthUsageCache()

    private var response: ClaudeOAuthUsageResponse?
    private var fetchedAt: Date?

    func value(maxAge: TimeInterval) -> ClaudeOAuthUsageResult? {
        guard let response, let fetchedAt, Date().timeIntervalSince(fetchedAt) < maxAge else { return nil }
        return ClaudeOAuthUsageResult(response: response, fetchedAt: fetchedAt)
    }

    func store(_ response: ClaudeOAuthUsageResponse, fetchedAt: Date) {
        self.response = response
        self.fetchedAt = fetchedAt
    }

    func invalidate() {
        self.response = nil
        self.fetchedAt = nil
    }
}

struct ClaudeOAuthUsageClient: Sendable {
    private let session: URLSession
    private let cache: ClaudeOAuthUsageCache

    init(session: URLSession = .shared, cache: ClaudeOAuthUsageCache = .shared) {
        self.session = session
        self.cache = cache
    }

    func fetch(accessToken: String) async throws -> ClaudeOAuthUsageResult {
        if let cached = await cache.value(maxAge: 5 * 60) {
            return cached
        }
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw ClaudeOAuthUsageError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeOAuthUsageError.invalidResponse }
        switch http.statusCode {
        case 200:
            guard let usage = try? JSONDecoder().decode(ClaudeOAuthUsageResponse.self, from: data) else {
                throw ClaudeOAuthUsageError.invalidResponse
            }
            let fetchedAt = Date.now
            await self.cache.store(usage, fetchedAt: fetchedAt)
            return ClaudeOAuthUsageResult(response: usage, fetchedAt: fetchedAt)
        case 401:
            throw ClaudeOAuthUsageError.unauthorized
        case 429:
            throw ClaudeOAuthUsageError.rateLimited
        default:
            throw ClaudeOAuthUsageError.server(http.statusCode)
        }
    }

    func invalidateCache() async {
        await self.cache.invalidate()
    }
}
