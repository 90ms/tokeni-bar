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

        let options = WindowsProviderSelectionFormatter.options(
            for: presentation)

        #expect(options == [
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

        let option = WindowsProviderSelectionFormatter.options(
            for: presentation).first

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
    func omitsInvalidIDsDuplicatesAndOptionsBeyondNativeCapacity() {
        var descriptors = (0..<20).map { index in
            Self.descriptor(
                id: ProviderID(rawValue: "provider-\(index)"),
                name: "Provider \(index)")
        }
        descriptors.insert(descriptors[0], at: 1)
        descriptors.insert(
            Self.descriptor(
                id: ProviderID(rawValue: "invalid\nprovider"),
                name: "Invalid"),
            at: 2)
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: descriptors,
            enabledProviderIDs: []))

        let options = WindowsProviderSelectionFormatter.options(
            for: presentation)

        #expect(options.count
            == WindowsProviderSelectionFormatter.maximumProviderCount)
        #expect(Set(options.map(\.providerID)).count == options.count)
        #expect(!options.contains {
            $0.providerID.rawValue.contains("\n")
        })
    }

    @Test
    func resolvesKnownToggleAndAllowsAllProvidersDisabled() {
        let descriptor = Self.descriptor(id: .codex, name: "Codex")
        let presentation = UsageApplicationPresentation(sessionState: .init(
            providerDescriptors: [descriptor],
            enabledProviderIDs: []))
        let options = WindowsProviderSelectionFormatter.options(
            for: presentation)

        let change = WindowsProviderSelectionFormatter.change(
            for: WindowsProviderSelectionToggle(
                rawProviderID: ProviderID.codex.rawValue,
                enabled: false),
            among: options)

        #expect(change == WindowsProviderSelectionChange(
            providerID: .codex,
            enabled: false))
        #expect(WindowsProviderSelectionFormatter.neutralMessage(
            for: presentation) != nil)
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
