import Foundation

public enum PricingCatalogSource: String, Hashable, Sendable {
    case bundled
    case cache
    case remote
}

public struct PricingCatalogUpdateResult: Hashable, Sendable {
    public let source: PricingCatalogSource
    public let metadata: PricingCatalogMetadata
    public let didActivateNewVersion: Bool

    public init(
        source: PricingCatalogSource,
        metadata: PricingCatalogMetadata,
        didActivateNewVersion: Bool)
    {
        self.source = source
        self.metadata = metadata
        self.didActivateNewVersion = didActivateNewVersion
    }
}

public enum PricingCatalogUpdateError: Error, Equatable, Sendable {
    case insecureURL
    case untrustedRemoteHost
    case invalidHTTPStatus(Int)
    case invalidResponse
    case manifestTooLarge
}

public actor PricingCatalogUpdateClient {
    public static let maximumManifestBytes = 512 * 1024
    public static let defaultRemoteURL = URL(
        string: "https://raw.githubusercontent.com/90ms/tokeni-bar/main/Sources/TokeniCore/Resources/token-pricing.json")!

    private let remoteURL: URL
    private let cacheURL: URL
    private let session: URLSession
    private let allowedRemoteHosts: Set<String>

    public init(
        remoteURL: URL = PricingCatalogUpdateClient.defaultRemoteURL,
        cacheURL: URL? = nil,
        session: URLSession = .shared,
        allowedRemoteHosts: Set<String> = ["raw.githubusercontent.com"])
    {
        self.remoteURL = remoteURL
        self.cacheURL = cacheURL ?? Self.defaultCacheURL
        self.session = session
        self.allowedRemoteHosts = Set(allowedRemoteHosts.map { $0.lowercased() })
    }

    public func activateCachedCatalog(at date: Date = .now) -> PricingCatalogUpdateResult {
        guard let data = try? Data(contentsOf: self.cacheURL),
              let manifest = try? TokenPricingCatalog.decodeAndValidate(data, at: date),
              let didActivate = try? TokenPricingCatalog.activate(manifest, at: date)
        else {
            return PricingCatalogUpdateResult(
                source: .bundled,
                metadata: TokenPricingCatalog.metadata,
                didActivateNewVersion: false)
        }
        return PricingCatalogUpdateResult(
            source: .cache,
            metadata: manifest.metadata,
            didActivateNewVersion: didActivate)
    }

    public func refresh(at date: Date = .now) async throws -> PricingCatalogUpdateResult {
        try self.validateRemoteURL(self.remoteURL)
        var request = URLRequest(url: self.remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PricingCatalogUpdateError.invalidResponse
        }
        if let finalURL = httpResponse.url {
            try self.validateRemoteURL(finalURL)
        }
        guard httpResponse.statusCode == 200 else {
            throw PricingCatalogUpdateError.invalidHTTPStatus(httpResponse.statusCode)
        }
        guard data.count <= Self.maximumManifestBytes else {
            throw PricingCatalogUpdateError.manifestTooLarge
        }

        let manifest = try TokenPricingCatalog.decodeAndValidate(data, at: date)
        let current = TokenPricingCatalog.manifest
        try TokenPricingCatalog.validateUpdate(manifest, replacing: current)

        try FileManager.default.createDirectory(
            at: self.cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: self.cacheURL, options: [.atomic])
        let didActivate = try TokenPricingCatalog.activate(manifest, at: date)
        return PricingCatalogUpdateResult(
            source: .remote,
            metadata: manifest.metadata,
            didActivateNewVersion: didActivate)
    }

    public func clearCache() throws {
        guard FileManager.default.fileExists(atPath: self.cacheURL.path) else { return }
        try FileManager.default.removeItem(at: self.cacheURL)
    }

    private func validateRemoteURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw PricingCatalogUpdateError.insecureURL
        }
        guard let host = url.host?.lowercased(), self.allowedRemoteHosts.contains(host) else {
            throw PricingCatalogUpdateError.untrustedRemoteHost
        }
    }

    private static var defaultCacheURL: URL {
        AppStoragePaths.applicationSupportDirectory()
            .appending(path: "token-pricing.json")
    }
}
