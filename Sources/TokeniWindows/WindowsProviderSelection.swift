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

public enum WindowsProviderSelectionFormatter {
    public static let maximumProviderCount = 16
    public static let maximumProviderIDByteCount = 63
    public static let maximumDisplayNameScalarCount = 80

    public static func options(
        for presentation: UsageApplicationPresentation)
        -> [WindowsProviderSelectionOption]
    {
        var seenProviderIDs: Set<ProviderID> = []
        return presentation.providerDescriptors.compactMap { descriptor in
            guard seenProviderIDs.insert(descriptor.id).inserted,
                  Self.isValidProviderID(descriptor.id.rawValue)
            else {
                return nil
            }
            return WindowsProviderSelectionOption(
                providerID: descriptor.id,
                displayName: Self.sanitizedDisplayName(
                    descriptor.displayName,
                    fallback: descriptor.id.rawValue),
                enabled: presentation.enabledProviderIDs.contains(descriptor.id))
        }
        .prefix(Self.maximumProviderCount)
        .map { $0 }
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

    public static func neutralMessage(
        for presentation: UsageApplicationPresentation) -> String?
    {
        guard !presentation.providerDescriptors.isEmpty,
              presentation.enabledProviderIDs.isEmpty
        else {
            return nil
        }
        return "All providers are disabled. Select a provider above to view usage."
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
