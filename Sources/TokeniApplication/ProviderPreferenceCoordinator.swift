import Foundation
import TokeniCore

/// The persisted provider selection exposed to application hosts.
public struct ProviderPreferenceState: Equatable, Sendable {
    public let enabledProviderIDs: Set<ProviderID>

    public init(enabledProviderIDs: Set<ProviderID>) {
        self.enabledProviderIDs = enabledProviderIDs
    }
}

/// Loads and saves provider selection without depending on a platform settings API.
///
/// Callers supply the currently known provider identifiers on every operation so
/// settings left behind by removed or unavailable providers cannot leak into the
/// active application state.
public struct ProviderPreferenceCoordinator: Sendable {
    private let settings: any SettingsStoring

    private static let enabledProviderIDsKey = "enabledProviderIDs"

    public init(settings: any SettingsStoring) {
        self.settings = settings
    }

    public func load(
        knownProviderIDs: Set<ProviderID>) -> ProviderPreferenceState
    {
        guard let storedProviderIDs = self.settings.stringArray(
            forKey: Self.enabledProviderIDsKey)
        else {
            return ProviderPreferenceState(
                enabledProviderIDs: knownProviderIDs)
        }

        let enabledProviderIDs = Set(
            storedProviderIDs.map(ProviderID.init(rawValue:)))
            .intersection(knownProviderIDs)
        return ProviderPreferenceState(
            enabledProviderIDs: enabledProviderIDs)
    }

    @discardableResult
    public func setEnabledProviderIDs(
        _ providerIDs: Set<ProviderID>,
        knownProviderIDs: Set<ProviderID>) -> ProviderPreferenceState
    {
        let enabledProviderIDs = providerIDs.intersection(knownProviderIDs)
        self.settings.set(
            enabledProviderIDs.map(\.rawValue).sorted(),
            forKey: Self.enabledProviderIDsKey)
        return ProviderPreferenceState(
            enabledProviderIDs: enabledProviderIDs)
    }

    @discardableResult
    public func setEnabled(
        _ enabled: Bool,
        for providerID: ProviderID,
        knownProviderIDs: Set<ProviderID>) -> ProviderPreferenceState
    {
        var state = self.load(knownProviderIDs: knownProviderIDs)
        guard knownProviderIDs.contains(providerID) else { return state }

        if enabled {
            state = ProviderPreferenceState(
                enabledProviderIDs: state.enabledProviderIDs.union([providerID]))
        } else {
            state = ProviderPreferenceState(
                enabledProviderIDs: state.enabledProviderIDs.subtracting([providerID]))
        }
        return self.setEnabledProviderIDs(
            state.enabledProviderIDs,
            knownProviderIDs: knownProviderIDs)
    }
}
