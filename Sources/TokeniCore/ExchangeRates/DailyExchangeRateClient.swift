import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ExchangeRateQuote: Codable, Hashable, Sendable {
    public let baseCurrency: String
    public let quoteCurrency: String
    public let rate: Double
    public let rateDate: String
    public let checkedAt: Date

    public init(
        baseCurrency: String,
        quoteCurrency: String,
        rate: Double,
        rateDate: String,
        checkedAt: Date)
    {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.rate = rate
        self.rateDate = rateDate
        self.checkedAt = checkedAt
    }
}

public actor DailyExchangeRateClient {
    private let cacheURL: URL
    private let endpoint: URL
    private var calendar: Calendar
    private var cachedQuote: ExchangeRateQuote?
    private var lastAttemptDay: Date?

    public init(
        cacheURL: URL? = nil,
        endpoint: URL = URL(
            string: "https://api.frankfurter.dev/v2/rate/USD/KRW?providers=ECB")!)
    {
        self.cacheURL = cacheURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "usd-krw-rate.json")
        self.endpoint = endpoint
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        self.calendar = calendar
    }

    public func quote(at now: Date = .now) async throws -> ExchangeRateQuote {
        let cached = try self.loadCachedQuote()
        if let cached, self.calendar.isDate(cached.checkedAt, inSameDayAs: now) {
            return cached
        }
        if let lastAttemptDay, self.calendar.isDate(lastAttemptDay, inSameDayAs: now) {
            if let cached { return cached }
            throw ExchangeRateError.unavailable
        }

        self.lastAttemptDay = now
        do {
            let (data, response) = try await URLSession.shared.data(from: self.endpoint)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode
            else { throw ExchangeRateError.invalidResponse }
            let rate = try JSONDecoder().decode(FrankfurterRateResponse.self, from: data)
            guard rate.base == "USD", rate.quote == "KRW", rate.rate > 0 else {
                throw ExchangeRateError.invalidResponse
            }
            let quote = ExchangeRateQuote(
                baseCurrency: rate.base,
                quoteCurrency: rate.quote,
                rate: rate.rate,
                rateDate: rate.date,
                checkedAt: now)
            try self.save(quote)
            self.cachedQuote = quote
            return quote
        } catch {
            if let cached { return cached }
            throw error
        }
    }

    private func loadCachedQuote() throws -> ExchangeRateQuote? {
        if let cachedQuote { return cachedQuote }
        guard FileManager.default.fileExists(atPath: self.cacheURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let quote = try decoder.decode(
            ExchangeRateQuote.self,
            from: Data(contentsOf: self.cacheURL))
        self.cachedQuote = quote
        return quote
    }

    private func save(_ quote: ExchangeRateQuote) throws {
        try FileManager.default.createDirectory(
            at: self.cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(quote).write(to: self.cacheURL, options: .atomic)
    }
}

private struct FrankfurterRateResponse: Decodable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}

private enum ExchangeRateError: Error {
    case invalidResponse
    case unavailable
}
