import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct StableAppRelease: Hashable, Sendable {
    public let version: SemanticVersion
    public let tagName: String
    public let name: String
    public let pageURL: URL
    public let publishedAt: Date?

    public init(
        version: SemanticVersion,
        tagName: String,
        name: String,
        pageURL: URL,
        publishedAt: Date?)
    {
        self.version = version
        self.tagName = tagName
        self.name = name
        self.pageURL = pageURL
        self.publishedAt = publishedAt
    }
}

public enum AppUpdateCheckSource: String, Hashable, Sendable {
    case remote
    case cache
}

public struct AppUpdateCheckResult: Hashable, Sendable {
    public let currentVersion: SemanticVersion
    public let latestRelease: StableAppRelease
    public let source: AppUpdateCheckSource
    public let checkedAt: Date
    public let isStale: Bool

    public var isUpdateAvailable: Bool {
        self.currentVersion < self.latestRelease.version
    }

    public init(
        currentVersion: SemanticVersion,
        latestRelease: StableAppRelease,
        source: AppUpdateCheckSource,
        checkedAt: Date,
        isStale: Bool)
    {
        self.currentVersion = currentVersion
        self.latestRelease = latestRelease
        self.source = source
        self.checkedAt = checkedAt
        self.isStale = isStale
    }
}

public enum AppUpdateCheckError: Error, Equatable, Sendable {
    case invalidCurrentVersion
    case insecureURL
    case untrustedHost
    case invalidHTTPStatus(Int)
    case invalidResponse
    case responseTooLarge
    case noStableRelease
}

public actor GitHubReleaseUpdateClient {
    public static let maximumResponseBytes = 1024 * 1024
    public static let defaultMinimumCheckInterval: TimeInterval = 6 * 60 * 60
    public static let defaultEndpoint = URL(
        string: "https://api.github.com/repos/90ms/tokeni-bar/releases?per_page=20")!
    public static let defaultLatestReleasePageURL = URL(
        string: "https://github.com/90ms/tokeni-bar/releases/latest")!

    private let endpoint: URL
    private let latestReleasePageURL: URL
    private let cacheURL: URL
    private let minimumCheckInterval: TimeInterval
    private let allowedAPIHosts: Set<String>
    private let allowedReleaseHosts: Set<String>
    private let load: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private var memoryCache: CachedRelease?

    public init(
        endpoint: URL = GitHubReleaseUpdateClient.defaultEndpoint,
        latestReleasePageURL: URL = GitHubReleaseUpdateClient
            .defaultLatestReleasePageURL,
        cacheURL: URL? = nil,
        minimumCheckInterval: TimeInterval = GitHubReleaseUpdateClient.defaultMinimumCheckInterval,
        session: URLSession = .shared,
        allowedAPIHosts: Set<String> = ["api.github.com"],
        allowedReleaseHosts: Set<String> = ["github.com"])
    {
        self.endpoint = endpoint
        self.latestReleasePageURL = latestReleasePageURL
        self.cacheURL = cacheURL ?? Self.defaultCacheURL
        self.minimumCheckInterval = max(0, minimumCheckInterval)
        self.allowedAPIHosts = Set(allowedAPIHosts.map { $0.lowercased() })
        self.allowedReleaseHosts = Set(allowedReleaseHosts.map { $0.lowercased() })
        self.load = { request in
            try await session.data(for: request)
        }
        self.memoryCache = nil
    }

    init(
        endpoint: URL = GitHubReleaseUpdateClient.defaultEndpoint,
        latestReleasePageURL: URL = GitHubReleaseUpdateClient
            .defaultLatestReleasePageURL,
        cacheURL: URL,
        minimumCheckInterval: TimeInterval = GitHubReleaseUpdateClient.defaultMinimumCheckInterval,
        allowedAPIHosts: Set<String> = ["api.github.com"],
        allowedReleaseHosts: Set<String> = ["github.com"],
        load: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse))
    {
        self.endpoint = endpoint
        self.latestReleasePageURL = latestReleasePageURL
        self.cacheURL = cacheURL
        self.minimumCheckInterval = max(0, minimumCheckInterval)
        self.allowedAPIHosts = Set(allowedAPIHosts.map { $0.lowercased() })
        self.allowedReleaseHosts = Set(allowedReleaseHosts.map { $0.lowercased() })
        self.load = load
        self.memoryCache = nil
    }

    public func check(
        currentVersion value: String,
        force: Bool = false,
        at now: Date = .now) async throws -> AppUpdateCheckResult
    {
        guard let currentVersion = SemanticVersion(value) else {
            throw AppUpdateCheckError.invalidCurrentVersion
        }
        try self.validateURL(self.endpoint, allowedHosts: self.allowedAPIHosts)
        try self.validateURL(
            self.latestReleasePageURL,
            allowedHosts: self.allowedReleaseHosts)
        let cached = self.memoryCache ?? (try? self.loadCache())
        self.memoryCache = cached

        if !force,
           let cached,
           now >= cached.checkedAt,
           now.timeIntervalSince(cached.checkedAt) < self.minimumCheckInterval
        {
            return self.makeResult(
                currentVersion: currentVersion,
                cached: cached,
                isStale: false)
        }

        do {
            let release: StableAppRelease
            do {
                release = try await self.fetchLatestStableReleaseFromAPI()
            } catch AppUpdateCheckError.invalidHTTPStatus(403) {
                release = try await self.fetchLatestStableReleasePage()
            } catch AppUpdateCheckError.invalidHTTPStatus(429) {
                release = try await self.fetchLatestStableReleasePage()
            }
            let cache = CachedRelease(checkedAt: now, release: release)
            self.memoryCache = cache
            // A validated remote result must not fail only because the
            // optional on-disk cache cannot be replaced. Keep the actor-local
            // value for throttling; a later remote refresh can retry persistence.
            try? self.save(cache)
            return AppUpdateCheckResult(
                currentVersion: currentVersion,
                latestRelease: release,
                source: .remote,
                checkedAt: now,
                isStale: false)
        } catch {
            guard let cached else { throw error }
            return self.makeResult(
                currentVersion: currentVersion,
                cached: cached,
                isStale: true)
        }
    }

    private func fetchLatestStableReleaseFromAPI() async throws -> StableAppRelease {
        var request = URLRequest(url: self.endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TokeniBar", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await self.load(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateCheckError.invalidResponse
        }
        if let finalURL = httpResponse.url {
            try self.validateURL(finalURL, allowedHosts: self.allowedAPIHosts)
        }
        guard httpResponse.statusCode == 200 else {
            throw AppUpdateCheckError.invalidHTTPStatus(httpResponse.statusCode)
        }
        if httpResponse.expectedContentLength > Self.maximumResponseBytes ||
            data.count > Self.maximumResponseBytes
        {
            throw AppUpdateCheckError.responseTooLarge
        }
        return try self.decodeLatestStableRelease(data)
    }

    private func fetchLatestStableReleasePage() async throws -> StableAppRelease {
        var request = URLRequest(url: self.latestReleasePageURL)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("TokeniBar", forHTTPHeaderField: "User-Agent")
        let (_, response) = try await self.load(request)
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url
        else {
            throw AppUpdateCheckError.invalidResponse
        }
        try self.validateURL(finalURL, allowedHosts: self.allowedReleaseHosts)
        guard httpResponse.statusCode == 200 else {
            throw AppUpdateCheckError.invalidHTTPStatus(httpResponse.statusCode)
        }
        let expectedPrefix = "/90ms/tokeni-bar/releases/tag/"
        guard finalURL.path.hasPrefix(expectedPrefix) else {
            throw AppUpdateCheckError.invalidResponse
        }
        let tagName = String(finalURL.path.dropFirst(expectedPrefix.count))
        guard !tagName.isEmpty,
              !tagName.contains("/"),
              finalURL.query == nil,
              finalURL.fragment == nil,
              let version = SemanticVersion(tagName),
              version.prerelease.isEmpty
        else {
            throw AppUpdateCheckError.invalidResponse
        }
        return StableAppRelease(
            version: version,
            tagName: tagName,
            name: tagName,
            pageURL: finalURL,
            publishedAt: nil)
    }

    public func clearCache() throws {
        self.memoryCache = nil
        guard FileManager.default.fileExists(atPath: self.cacheURL.path) else { return }
        try FileManager.default.removeItem(at: self.cacheURL)
    }

    private func decodeLatestStableRelease(_ data: Data) throws -> StableAppRelease {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let responses = try? decoder.decode([GitHubReleaseResponse].self, from: data) else {
            throw AppUpdateCheckError.invalidResponse
        }
        let releases = try responses.compactMap { response -> StableAppRelease? in
            guard !response.draft, !response.prerelease,
                  let version = SemanticVersion(response.tagName),
                  version.prerelease.isEmpty
            else { return nil }
            try self.validateURL(response.pageURL, allowedHosts: self.allowedReleaseHosts)
            return StableAppRelease(
                version: version,
                tagName: response.tagName,
                name: response.name?.isEmpty == false ? response.name! : response.tagName,
                pageURL: response.pageURL,
                publishedAt: response.publishedAt)
        }
        guard let latest = releases.max(by: { $0.version < $1.version }) else {
            throw AppUpdateCheckError.noStableRelease
        }
        return latest
    }

    private func makeResult(
        currentVersion: SemanticVersion,
        cached: CachedRelease,
        isStale: Bool) -> AppUpdateCheckResult
    {
        AppUpdateCheckResult(
            currentVersion: currentVersion,
            latestRelease: cached.release,
            source: .cache,
            checkedAt: cached.checkedAt,
            isStale: isStale)
    }

    private func loadCache() throws -> CachedRelease {
        let attributes = try FileManager.default.attributesOfItem(atPath: self.cacheURL.path)
        guard let size = attributes[.size] as? NSNumber,
              size.intValue <= Self.maximumResponseBytes
        else { throw AppUpdateCheckError.responseTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(CachedPayload.self, from: Data(contentsOf: self.cacheURL))
        guard let version = SemanticVersion(payload.tagName), version.prerelease.isEmpty else {
            throw AppUpdateCheckError.invalidResponse
        }
        try self.validateURL(payload.pageURL, allowedHosts: self.allowedReleaseHosts)
        return CachedRelease(
            checkedAt: payload.checkedAt,
            release: StableAppRelease(
                version: version,
                tagName: payload.tagName,
                name: payload.name,
                pageURL: payload.pageURL,
                publishedAt: payload.publishedAt))
    }

    private func save(_ cache: CachedRelease) throws {
        let payload = CachedPayload(
            checkedAt: cache.checkedAt,
            tagName: cache.release.tagName,
            name: cache.release.name,
            pageURL: cache.release.pageURL,
            publishedAt: cache.release.publishedAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        try FileManager.default.createDirectory(
            at: self.cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        #if os(Windows)
        // swift-foundation's atomic Data writer can fail with a Win32 sharing
        // violation even for a new cache target. This file is an optional,
        // fully validated cache, so a partial write safely degrades to a
        // remote refresh on the next launch.
        try data.write(to: self.cacheURL)
        #else
        try data.write(to: self.cacheURL, options: .atomic)
        #endif
    }

    private func validateURL(_ url: URL, allowedHosts: Set<String>) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw AppUpdateCheckError.insecureURL
        }
        guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
            throw AppUpdateCheckError.untrustedHost
        }
        guard url.user == nil, url.password == nil else {
            throw AppUpdateCheckError.untrustedHost
        }
    }

    private static var defaultCacheURL: URL {
        AppStoragePaths.applicationSupportDirectory()
            .appending(path: "latest-release.json")
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let name: String?
    let pageURL: URL
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case pageURL = "html_url"
        case draft
        case prerelease
        case publishedAt = "published_at"
    }
}

private struct CachedRelease {
    let checkedAt: Date
    let release: StableAppRelease
}

private struct CachedPayload: Codable {
    let checkedAt: Date
    let tagName: String
    let name: String
    let pageURL: URL
    let publishedAt: Date?
}
