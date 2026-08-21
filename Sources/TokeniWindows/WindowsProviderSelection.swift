import Foundation
import TokeniApplication
import TokeniCore

public struct WindowsProviderSelectionOption: Equatable, Sendable {
    public let providerID: ProviderID
    public let displayName: String
    public let enabled: Bool

    public init(providerID: ProviderID, displayName: String, enabled: Bool) {
        self.providerID = providerID
        self.displayName = displayName
        self.enabled = enabled
    }
}

public struct WindowsProviderSelectionToggle: Equatable, Sendable {
    public let rawProviderID: String
    public let enabled: Bool

    public init(rawProviderID: String, enabled: Bool) {
        self.rawProviderID = rawProviderID
        self.enabled = enabled
    }
}

public struct WindowsProviderSelectionChange: Equatable, Sendable {
    public let providerID: ProviderID
    public let enabled: Bool
}

public struct WindowsProviderSelectionSnapshot: Equatable, Sendable {
    public let options: [WindowsProviderSelectionOption]
    public let unavailableMessage: String?
}

public enum WindowsProviderSelectionFormatter {
    public static let maximumProviderCount = 16
    public static let maximumProviderIDByteCount = 63
    public static let maximumDisplayNameScalarCount = 80

    public static let neutralMessage =
        "All providers are disabled. Select a provider above to view usage."
    public static let unavailableMessage =
        "Provider selection is unavailable in this Windows build."

    public static func snapshot(
        for presentation: UsageApplicationPresentation)
        -> WindowsProviderSelectionSnapshot
    {
        guard presentation.providerDescriptors.count
                <= Self.maximumProviderCount
        else {
            return WindowsProviderSelectionSnapshot(
                options: [],
                unavailableMessage: Self.unavailableMessage)
        }

        var seenProviderIDs: Set<ProviderID> = []
        var options: [WindowsProviderSelectionOption] = []
        for descriptor in presentation.providerDescriptors {
            guard seenProviderIDs.insert(descriptor.id).inserted,
                  Self.isValidProviderID(descriptor.id.rawValue)
            else {
                return WindowsProviderSelectionSnapshot(
                    options: [],
                    unavailableMessage: Self.unavailableMessage)
            }
            options.append(WindowsProviderSelectionOption(
                providerID: descriptor.id,
                displayName: Self.sanitizedDisplayName(
                    descriptor.displayName,
                    fallback: descriptor.id.rawValue),
                enabled: presentation.enabledProviderIDs.contains(descriptor.id)))
        }
        return WindowsProviderSelectionSnapshot(
            options: options,
            unavailableMessage: nil)
    }

    public static func change(
        for toggle: WindowsProviderSelectionToggle,
        among options: [WindowsProviderSelectionOption])
        -> WindowsProviderSelectionChange?
    {
        guard toggle.rawProviderID.utf8.count
                <= Self.maximumProviderIDByteCount,
              let option = options.first(where: {
                  $0.providerID.rawValue == toggle.rawProviderID
              })
        else {
            return nil
        }
        return WindowsProviderSelectionChange(
            providerID: option.providerID,
            enabled: toggle.enabled)
    }

    public static func dashboardMessage(
        for presentation: UsageApplicationPresentation,
        snapshot: WindowsProviderSelectionSnapshot) -> String?
    {
        if let unavailableMessage = snapshot.unavailableMessage {
            return unavailableMessage
        }
        guard !presentation.providerDescriptors.isEmpty,
              presentation.enabledProviderIDs.isEmpty
        else {
            return nil
        }
        return Self.neutralMessage
    }

    static func sanitizedDisplayName(
        _ displayName: String,
        fallback: String) -> String
    {
        let visibleScalars = displayName.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        let limited = String(
            String.UnicodeScalarView(
                visibleScalars.prefix(Self.maximumDisplayNameScalarCount)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return limited.isEmpty ? fallback : limited
    }

    private static func isValidProviderID(_ rawValue: String) -> Bool {
        !rawValue.isEmpty
            && rawValue.utf8.count <= Self.maximumProviderIDByteCount
            && rawValue.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}

enum WindowsProviderToggleScheduler {
    static let pollingInterval = Duration.milliseconds(150)

    static func shouldPublish(
        previous: WindowsProviderSelectionSnapshot?,
        current: WindowsProviderSelectionSnapshot,
        persisted: Bool) -> Bool
    {
        // Persistence forces an authoritative commit even when the state is
        // equal to the last published snapshot. This is what acknowledges an
        // ABA sequence whose final value returned to its original value.
        persisted || previous != current
    }

    static func drain(
        knownOptions: [WindowsProviderSelectionOption],
        take: @Sendable () -> WindowsProviderSelectionToggle?,
        persist: @Sendable (WindowsProviderSelectionChange) async -> Void)
        async -> Bool
    {
        var persisted = false
        while let toggle = take() {
            guard let change = WindowsProviderSelectionFormatter.change(
                for: toggle,
                among: knownOptions)
            else {
                continue
            }
            await persist(change)
            persisted = true
        }
        return persisted
    }
}

actor WindowsProviderRefreshSignal {
    private var requestedRevision = 0

    func request() {
        self.requestedRevision += 1
    }

    func revision() -> Int {
        self.requestedRevision
    }
}
