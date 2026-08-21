import Foundation
import Testing
import TokeniApplication
import TokeniCore
@testable import TokeniWindows

struct WindowsProviderSelectionTests {
    @Test
    func formatsKnownProvidersInDescriptorOrderWithEnabledState() {
        let descriptors = [
            Self.descriptor(id: .codex, name: "Codex"),
            Self.descriptor(id: .claude, name: "Claude Code"),
        ]
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: descriptors,
            enabledProviderIDs: [.claude]))

        let snapshot = WindowsProviderSelectionFormatter.snapshot(
            for: presentation)

        #expect(snapshot.unavailableMessage == nil)
        #expect(snapshot.options == [
            WindowsProviderSelectionOption(
                providerID: .codex,
                displayName: "Codex",
                enabled: false),
            WindowsProviderSelectionOption(
                providerID: .claude,
                displayName: "Claude Code",
                enabled: true),
        ])
    }

    @Test
    func sanitizesAndBoundsDisplayNames() {
        let longName = "Claude\n\u{0000}" + String(repeating: "x", count: 100)
        let descriptor = Self.descriptor(id: .claude, name: longName)
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: [descriptor],
            enabledProviderIDs: [.claude]))

        let option = WindowsProviderSelectionFormatter.snapshot(
            for: presentation).options.first

        #expect(option?.displayName.contains("\n") == false)
        #expect(option?.displayName.contains("\u{0000}") == false)
        #expect(option?.displayName.unicodeScalars.count
            == WindowsProviderSelectionFormatter.maximumDisplayNameScalarCount)
    }

    @Test
    func rejectsUnknownOrStaleToggleIDs() {
        let option = WindowsProviderSelectionOption(
            providerID: .codex,
            displayName: "Codex",
            enabled: true)

        let change = WindowsProviderSelectionFormatter.change(
            for: WindowsProviderSelectionToggle(
                rawProviderID: "removed-provider",
                enabled: false),
            among: [option])

        #expect(change == nil)
    }

    @Test
    func reportsOverflowWithoutReturningAPartialList() {
        let descriptors = (0...WindowsProviderSelectionFormatter
            .maximumProviderCount).map { index in
            Self.descriptor(
                id: ProviderID(rawValue: "provider-\(index)"),
                name: "Provider \(index)")
        }
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: descriptors,
            enabledProviderIDs: []))

        let snapshot = WindowsProviderSelectionFormatter.snapshot(
            for: presentation)

        #expect(snapshot.options.isEmpty)
        #expect(snapshot.unavailableMessage
            == WindowsProviderSelectionFormatter.unavailableMessage)
        #expect(WindowsProviderSelectionFormatter.dashboardMessage(
            for: presentation,
            snapshot: snapshot)
            == WindowsProviderSelectionFormatter.unavailableMessage)
    }

    @Test
    func accepts63ByteIDAndRejects64ByteIDWithoutPartialOptions() {
        let acceptedID = ProviderID(rawValue: String(repeating: "a", count: 63))
        let rejectedID = ProviderID(rawValue: String(repeating: "b", count: 64))
        let acceptedPresentation = UsageApplicationPresentation(
            sessionState: .init(providerDescriptors: [
                Self.descriptor(id: acceptedID, name: "Accepted"),
            ]))
        let rejectedPresentation = UsageApplicationPresentation(
            sessionState: .init(providerDescriptors: [
                Self.descriptor(id: acceptedID, name: "Accepted"),
                Self.descriptor(id: rejectedID, name: "Rejected"),
            ]))

        #expect(WindowsProviderSelectionFormatter.snapshot(
            for: acceptedPresentation).options.map(\.providerID) == [acceptedID])
        let rejected = WindowsProviderSelectionFormatter.snapshot(
            for: rejectedPresentation)
        #expect(rejected.options.isEmpty)
        #expect(rejected.unavailableMessage != nil)
    }

    @Test
    func usesProviderIDWhenSanitizedDisplayNameIsBlank() {
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: [
                Self.descriptor(id: .codex, name: " \n\t "),
            ]))

        let option = WindowsProviderSelectionFormatter.snapshot(
            for: presentation).options.first

        #expect(option?.displayName == ProviderID.codex.rawValue)
    }

    @Test
    func resolvesKnownToggleAndAllowsAllProvidersDisabled() {
        let descriptor = Self.descriptor(id: .codex, name: "Codex")
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: [descriptor],
            enabledProviderIDs: []))
        let snapshot = WindowsProviderSelectionFormatter.snapshot(
            for: presentation)

        let change = WindowsProviderSelectionFormatter.change(
            for: WindowsProviderSelectionToggle(
                rawProviderID: ProviderID.codex.rawValue,
                enabled: false),
            among: snapshot.options)

        #expect(change == WindowsProviderSelectionChange(
            providerID: .codex,
            enabled: false))
        #expect(WindowsProviderSelectionFormatter.dashboardMessage(
            for: presentation,
            snapshot: snapshot)
            == WindowsProviderSelectionFormatter.neutralMessage)
    }

    @Test
    func neutralMessageIsNilWithoutKnownProvidersOrWhenOneIsEnabled() {
        let empty = UsageApplicationPresentation(sessionState: .init())
        let enabled = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: [Self.descriptor(id: .codex, name: "Codex")],
            enabledProviderIDs: [.codex]))

        #expect(WindowsProviderSelectionFormatter.dashboardMessage(
            for: empty,
            snapshot: WindowsProviderSelectionFormatter.snapshot(for: empty)) == nil)
        #expect(WindowsProviderSelectionFormatter.dashboardMessage(
            for: enabled,
            snapshot: WindowsProviderSelectionFormatter.snapshot(for: enabled)) == nil)
    }

    @Test
    func defaultRegistryFitsNativeProviderCapacity() {
        #expect(ProviderRegistry.defaultProviders().count
            <= WindowsProviderSelectionFormatter.maximumProviderCount)
    }

    @Test
    func fastDrainPersistsAllKnownFinalStatesAndSkipsStaleIDs() async {
        let source = ToggleSource([
            WindowsProviderSelectionToggle(rawProviderID: "removed", enabled: true),
            WindowsProviderSelectionToggle(rawProviderID: "codex", enabled: false),
            WindowsProviderSelectionToggle(rawProviderID: "claude", enabled: true),
        ])
        let recorder = ChangeRecorder()
        let options = [
            WindowsProviderSelectionOption(
                providerID: .codex,
                displayName: "Codex",
                enabled: true),
            WindowsProviderSelectionOption(
                providerID: .claude,
                displayName: "Claude Code",
                enabled: false),
        ]

        let persisted = await WindowsProviderToggleScheduler.drain(
            knownOptions: options,
            take: { source.take() },
            persist: { await recorder.append($0) })

        #expect(persisted)
        #expect(await recorder.changes() == [
            WindowsProviderSelectionChange(providerID: .codex, enabled: false),
            WindowsProviderSelectionChange(providerID: .claude, enabled: true),
        ])
    }

    @Test
    func publishingForcesAuthoritativeAckAfterABAPersistence() {
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: [Self.descriptor(id: .codex, name: "Codex")],
            enabledProviderIDs: [.codex]))
        let snapshot = WindowsProviderSelectionFormatter.snapshot(
            for: presentation)

        #expect(!WindowsProviderToggleScheduler.shouldPublish(
            previous: snapshot,
            current: snapshot,
            persisted: false))
        #expect(WindowsProviderToggleScheduler.shouldPublish(
            previous: snapshot,
            current: snapshot,
            persisted: true))
        #expect(WindowsProviderToggleScheduler.shouldPublish(
            previous: nil,
            current: snapshot,
            persisted: false))
    }

    private static func descriptor(
        id: ProviderID,
        name: String) -> ProviderDescriptor
    {
        ProviderDescriptor(
            id: id,
            displayName: name,
            shortName: name,
            systemImage: "circle",
            capabilities: ProviderCapabilities())
    }
}

private final class ToggleSource: @unchecked Sendable {
    private let lock = NSLock()
    private var toggles: [WindowsProviderSelectionToggle]

    init(_ toggles: [WindowsProviderSelectionToggle]) {
        self.toggles = toggles
    }

    func take() -> WindowsProviderSelectionToggle? {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard !self.toggles.isEmpty else { return nil }
        return self.toggles.removeFirst()
    }
}

private actor ChangeRecorder {
    private var recorded: [WindowsProviderSelectionChange] = []

    func append(_ change: WindowsProviderSelectionChange) {
        self.recorded.append(change)
    }

    func changes() -> [WindowsProviderSelectionChange] {
        self.recorded
    }
}
