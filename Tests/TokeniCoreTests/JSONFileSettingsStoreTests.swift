import Foundation
import Testing
@testable import TokeniCore

@Suite("JSON file settings store")
struct JSONFileSettingsStoreTests {
    @Test("Round-trips every supported settings value")
    func roundTripsSupportedValues() {
        let file = self.temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let original = JSONFileSettingsStore(fileURL: file)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        original.set(true, forKey: "enabled")
        original.set(42, forKey: "count")
        original.set(2.5, forKey: "ratio")
        original.set("ko", forKey: "language")
        original.set(["codex", "claude"], forKey: "providers")
        original.set(date, forKey: "updatedAt")

        let reloaded = JSONFileSettingsStore(fileURL: file)
        #expect(reloaded.containsValue(forKey: "enabled"))
        #expect(reloaded.bool(forKey: "enabled"))
        #expect(reloaded.integer(forKey: "count") == 42)
        #expect(reloaded.double(forKey: "ratio") == 2.5)
        #expect(reloaded.string(forKey: "language") == "ko")
        #expect(reloaded.stringArray(forKey: "providers") == ["codex", "claude"])
        #expect(reloaded.date(forKey: "updatedAt") == date)

        reloaded.removeValue(forKey: "enabled")
        #expect(!JSONFileSettingsStore(fileURL: file).containsValue(forKey: "enabled"))
    }

    @Test("Missing files return contract defaults")
    func missingFileReturnsDefaults() {
        let file = self.temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let store = JSONFileSettingsStore(fileURL: file)
        #expect(!store.containsValue(forKey: "missing"))
        #expect(!store.bool(forKey: "missing"))
        #expect(store.integer(forKey: "missing") == 0)
        #expect(store.double(forKey: "missing") == 0)
        #expect(store.string(forKey: "missing") == nil)
        #expect(store.stringArray(forKey: "missing") == nil)
        #expect(store.date(forKey: "missing") == nil)
    }

    @Test("Corrupt or unsupported JSON returns defaults")
    func corruptFileReturnsDefaults() throws {
        let file = self.temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: file)

        let store = JSONFileSettingsStore(fileURL: file)
        #expect(!store.containsValue(forKey: "count"))
        #expect(store.integer(forKey: "count") == 0)
        #expect(store.string(forKey: "count") == nil)

        try Data(#"{"values":{"count":{"type":"unsupported","value":42}}}"#.utf8)
            .write(to: file)
        let unsupportedStore = JSONFileSettingsStore(fileURL: file)
        #expect(!unsupportedStore.containsValue(forKey: "count"))
        #expect(unsupportedStore.integer(forKey: "count") == 0)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "settings.json")
    }
}
