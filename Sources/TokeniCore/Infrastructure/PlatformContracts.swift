import Foundation

/// The user and application directories needed by shared services.
///
/// The value is deliberately independent of a platform-specific path API. Each
/// executable supplies the appropriate macOS or Windows implementation.
public struct ApplicationDirectories: Equatable, Sendable {
    public let homeDirectory: URL
    public let applicationSupportDirectory: URL
    public let cachesDirectory: URL
    public let localApplicationSupportDirectory: URL

    public init(
        homeDirectory: URL,
        applicationSupportDirectory: URL,
        cachesDirectory: URL,
        localApplicationSupportDirectory: URL)
    {
        self.homeDirectory = homeDirectory
        self.applicationSupportDirectory = applicationSupportDirectory
        self.cachesDirectory = cachesDirectory
        self.localApplicationSupportDirectory = localApplicationSupportDirectory
    }
}

public protocol ApplicationDirectoriesProviding: Sendable {
    var directories: ApplicationDirectories { get }
}

/// Locates an executable without making provider code aware of PATH syntax,
/// executable extensions, or package-manager layout.
public protocol ExecutableLocating: Sendable {
    func locate(
        executableNames: [String],
        pathEnvironment: String?,
        homeDirectory: URL) -> URL?
}

/// Queries a local SQLite database without exposing its process or library
/// implementation to a provider parser.
public protocol ReadOnlySQLiteQuerying: Sendable {
    func queryJSON(databaseURL: URL, sql: String) async throws -> Data
}

/// Stores the small set of property-list values used by application settings.
///
/// The contract keeps shared application code independent from UserDefaults so
/// the Windows client can provide a file-backed implementation later without
/// changing preference keys or state models.
public protocol SettingsStoring: Sendable {
    func containsValue(forKey key: String) -> Bool
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func string(forKey key: String) -> String?
    func stringArray(forKey key: String) -> [String]?
    func date(forKey key: String) -> Date?

    func set(_ value: Bool, forKey key: String)
    func set(_ value: Int, forKey key: String)
    func set(_ value: Double, forKey key: String)
    func set(_ value: String, forKey key: String)
    func set(_ value: [String], forKey key: String)
    func set(_ value: Date, forKey key: String)
    func removeValue(forKey key: String)
}

public struct AppNotification: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

public protocol NotificationDelivering: Sendable {
    func requestAuthorization() async throws
    func deliver(_ notification: AppNotification) async throws
}

public protocol LaunchAtLoginManaging: Sendable {
    func isEnabled() async -> Bool
    func setEnabled(_ enabled: Bool) async throws
}

public protocol AppUpdateInstalling: Sendable {
    func install(update: AppUpdateCheckResult) async throws
}

enum PlatformEnvironment {
    #if os(Windows)
    static let pathSeparator: Character = ";"
    #else
    static let pathSeparator: Character = ":"
    #endif

    static func pathEntries(_ value: String?) -> [String] {
        (value ?? "")
            .split(separator: self.pathSeparator)
            .map(String.init)
    }

    static func pathValue(from environment: [String: String]) -> String? {
        environment["PATH"] ?? environment["Path"]
    }

    static func joinedPath(_ entries: [String]) -> String {
        entries.joined(separator: String(self.pathSeparator))
    }
}
