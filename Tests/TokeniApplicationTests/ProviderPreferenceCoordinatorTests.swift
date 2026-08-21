import Foundation
import Testing
@testable import TokeniApplication
import TokeniCore

struct ProviderPreferenceCoordinatorTests {
    @Test
    func enablesEveryKnownProviderWhenThePreferenceIsMissing() {
        let fixture = Self.fixture()
        defer { fixture.remove() }
        let coordinator = ProviderPreferenceCoordinator(settings: fixture.store)

        let state = coordinator.load(
            knownProviderIDs: [.codex, .claude])

        #expect(state.enabledProviderIDs == [.codex, .claude])
        #expect(!fixture.store.containsValue(forKey: "enabledProviderIDs"))
    }

    @Test
    func filtersUnknownStoredProviders() {
        let fixture = Self.fixture()
        defer { fixture.remove() }
        fixture.store.set(
            [ProviderID.codex.rawValue, "removed-provider"],
            forKey: "enabledProviderIDs")
        let coordinator = ProviderPreferenceCoordinator(settings: fixture.store)

        let state = coordinator.load(
            knownProviderIDs: [.codex, .claude])

        #expect(state.enabledProviderIDs == [.codex])
    }

    @Test
    func persistsEnablementChangesAcrossStoreInstances() {
        let fixture = Self.fixture()
        defer { fixture.remove() }
        let coordinator = ProviderPreferenceCoordinator(settings: fixture.store)
        let knownProviderIDs: Set<ProviderID> = [.codex, .claude]

        let disabled = coordinator.setEnabled(
            false,
            for: .claude,
            knownProviderIDs: knownProviderIDs)
        #expect(disabled.enabledProviderIDs == [.codex])

        let reloadedStore = JSONFileSettingsStore(fileURL: fixture.fileURL)
        let reloaded = ProviderPreferenceCoordinator(settings: reloadedStore)
            .load(knownProviderIDs: knownProviderIDs)
        #expect(reloaded.enabledProviderIDs == [.codex])

        let enabled = ProviderPreferenceCoordinator(settings: reloadedStore)
            .setEnabled(
                true,
                for: .claude,
                knownProviderIDs: knownProviderIDs)
        #expect(enabled.enabledProviderIDs == knownProviderIDs)
    }

    @Test
    func filtersAndStoresProviderIdentifiersInDeterministicOrder() {
        let fixture = Self.fixture()
        defer { fixture.remove() }
        let coordinator = ProviderPreferenceCoordinator(settings: fixture.store)
        let unknown = ProviderID(rawValue: "removed-provider")

        let state = coordinator.setEnabledProviderIDs(
            [.codex, .claude, unknown],
            knownProviderIDs: [.codex, .claude])

        #expect(state.enabledProviderIDs == [.codex, .claude])
        #expect(fixture.store.stringArray(forKey: "enabledProviderIDs") == [
            ProviderID.claude.rawValue,
            ProviderID.codex.rawValue,
        ])
    }

    private static func fixture() -> SettingsFixture {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "settings.json")
        return SettingsFixture(
            directory: directory,
            fileURL: fileURL,
            store: JSONFileSettingsStore(fileURL: fileURL))
    }
}

private struct SettingsFixture {
    let directory: URL
    let fileURL: URL
    let store: JSONFileSettingsStore

    func remove() {
        try? FileManager.default.removeItem(at: self.directory)
    }
}
