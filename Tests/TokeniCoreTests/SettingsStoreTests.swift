import Foundation
import Testing
@testable import TokeniCore

#if canImport(Darwin)
struct SettingsStoreTests {
    @Test
    func preservesTypedSettingsAndDistinguishesMissingValues() {
        let suiteName = "TokeniBar.SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(!store.containsValue(forKey: "missing"))
        store.set(true, forKey: "enabled")
        store.set(42, forKey: "count")
        store.set(2.5, forKey: "ratio")
        store.set("ko", forKey: "language")
        store.set(["codex", "claude"], forKey: "providers")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.set(date, forKey: "date")

        #expect(store.containsValue(forKey: "enabled"))
        #expect(store.bool(forKey: "enabled"))
        #expect(store.integer(forKey: "count") == 42)
        #expect(store.double(forKey: "ratio") == 2.5)
        #expect(store.string(forKey: "language") == "ko")
        #expect(store.stringArray(forKey: "providers") == ["codex", "claude"])
        #expect(store.date(forKey: "date") == date)

        store.removeValue(forKey: "enabled")
        #expect(!store.containsValue(forKey: "enabled"))
    }
}
#endif
