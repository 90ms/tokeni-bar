import Foundation

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

        init(hasCredits: Bool, unlimited: Bool, balance: String?) {
            self.hasCredits = hasCredits
            self.unlimited = unlimited
            self.balance = balance
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
    let quotaResetCredits: QuotaResetCreditSummary?

    init(
        response: CodexAccountUsageResponse,
        fetchedAt: Date,
        quotaResetCredits: QuotaResetCreditSummary? = nil)
    {
        self.response = response
        self.fetchedAt = fetchedAt
        self.quotaResetCredits = quotaResetCredits
    }
}

actor CodexAccountUsageCache {
    static let shared = CodexAccountUsageCache()

    private var response: CodexAccountUsageResponse?
    private var quotaResetCredits: QuotaResetCreditSummary?
    private var accountID: String?
    private var fetchedAt: Date?
    private var cachedFailure: (error: CodexCLIUsageError, retryAt: Date)?

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
        return CodexAccountUsageResult(
            response: response,
            fetchedAt: fetchedAt,
            quotaResetCredits: self.quotaResetCredits)
    }

    func store(
        _ response: CodexAccountUsageResponse,
        accountID: String?,
        fetchedAt: Date,
        quotaResetCredits: QuotaResetCreditSummary? = nil)
    {
        self.response = response
        self.accountID = accountID
        self.fetchedAt = fetchedAt
        self.quotaResetCredits = quotaResetCredits
        self.cachedFailure = nil
    }

    func failure(now: Date = .now) -> CodexCLIUsageError? {
        guard let failure = self.cachedFailure else { return nil }
        guard now < failure.retryAt else {
            self.cachedFailure = nil
            return nil
        }
        return failure.error
    }

    func storeFailure(
        _ error: CodexCLIUsageError,
        retryAfter: TimeInterval,
        now: Date = .now)
    {
        self.cachedFailure = (
            error: error,
            retryAt: now.addingTimeInterval(max(retryAfter, 0)))
    }

    func invalidate() {
        self.response = nil
        self.quotaResetCredits = nil
        self.accountID = nil
        self.fetchedAt = nil
        self.cachedFailure = nil
    }
}

struct CodexAccountUsageClient: Sendable {
    private let locator: CodexExecutableLocator
    private let cache: CodexAccountUsageCache
    private let cacheMaxAge: TimeInterval
    private let timeout: TimeInterval
    private let homeDirectory: URL

    private static let failureRetryInterval: TimeInterval = 90

    init(
        executableURL: URL? = nil,
        pathEnvironment: String? = PlatformEnvironment.pathValue(
            from: ProcessInfo.processInfo.environment),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        cache: CodexAccountUsageCache = .shared,
        cacheMaxAge: TimeInterval = 60,
        timeout: TimeInterval = 15)
    {
        self.locator = .init(
            explicitURL: executableURL,
            pathEnvironment: pathEnvironment,
            homeDirectory: homeDirectory)
        self.cache = cache
        self.cacheMaxAge = cacheMaxAge
        self.timeout = timeout
        self.homeDirectory = homeDirectory
    }

    func fetch(forceRefresh: Bool = false) async throws -> CodexAccountUsageResult {
        if !forceRefresh,
           let cached = await self.cache.value(accountID: nil, maxAge: self.cacheMaxAge)
        {
            return cached
        }
        if !forceRefresh,
           let failure = await self.cache.failure()
        {
            throw failure
        }
        guard let executableURL = self.locator.resolve() else {
            let error = CodexAccountUsageError.executableUnavailable
            await self.cache.storeFailure(
                error,
                retryAfter: Self.failureRetryInterval)
            throw error
        }

        let runner = CodexAppServerUsageRunner(
            executableURL: executableURL,
            homeDirectory: self.homeDirectory)
        let cliResponse: CodexCLIRateLimitsResponse
        do {
            cliResponse = try await CodexAppServerClient.run(
                runner,
                request: CodexAppServerUsageRunner.rateLimitsRequest,
                responseID: 2,
                timeout: self.timeout)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CodexCLIUsageError {
            await self.cache.storeFailure(
                error,
                retryAfter: Self.failureRetryInterval)
            throw error
        } catch {
            let usageError = CodexAccountUsageError.invalidResponse
            await self.cache.storeFailure(
                usageError,
                retryAfter: Self.failureRetryInterval)
            throw usageError
        }
        guard let response = cliResponse.accountUsageResponse() else {
            let error = CodexAccountUsageError.invalidResponse
            await self.cache.storeFailure(
                error,
                retryAfter: Self.failureRetryInterval)
            throw error
        }
        let fetchedAt = Date.now
        let quotaResetCredits = cliResponse.quotaResetCreditsSummary()
        await self.cache.store(
            response,
            accountID: nil,
            fetchedAt: fetchedAt,
            quotaResetCredits: quotaResetCredits)
        return CodexAccountUsageResult(
            response: response,
            fetchedAt: fetchedAt,
            quotaResetCredits: quotaResetCredits)
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
