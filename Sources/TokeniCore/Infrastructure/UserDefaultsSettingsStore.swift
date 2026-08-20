import Foundation

#if canImport(Darwin)

/// macOS-compatible settings adapter. Windows can replace this implementation
/// with a file-backed adapter while sharing the same `SettingsStoring` contract.
public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func containsValue(forKey key: String) -> Bool {
        self.defaults.object(forKey: key) != nil
    }

    public func bool(forKey key: String) -> Bool {
        self.defaults.bool(forKey: key)
    }

    public func integer(forKey key: String) -> Int {
        self.defaults.integer(forKey: key)
    }

    public func double(forKey key: String) -> Double {
        self.defaults.double(forKey: key)
    }

    public func string(forKey key: String) -> String? {
        self.defaults.string(forKey: key)
    }

    public func stringArray(forKey key: String) -> [String]? {
        self.defaults.stringArray(forKey: key)
    }

    public func date(forKey key: String) -> Date? {
        self.defaults.object(forKey: key) as? Date
    }

    public func set(_ value: Bool, forKey key: String) {
        self.defaults.set(value, forKey: key)
    }

    public func set(_ value: Int, forKey key: String) {
        self.defaults.set(value, forKey: key)
    }

    public func set(_ value: Double, forKey key: String) {
        self.defaults.set(value, forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        self.defaults.set(value, forKey: key)
    }

    public func set(_ value: [String], forKey key: String) {
        self.defaults.set(value, forKey: key)
    }

    public func set(_ value: Date, forKey key: String) {
        self.defaults.set(value, forKey: key)
    }

    public func removeValue(forKey key: String) {
        self.defaults.removeObject(forKey: key)
    }
}

#endif
