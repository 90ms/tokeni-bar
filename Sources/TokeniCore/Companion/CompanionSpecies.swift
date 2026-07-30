import Foundation

public enum CompanionSpeciesID: String, Codable, CaseIterable, Hashable, Sendable {
    case bytebot
    case cachecat
    case stackfox
    case promptpup
    case nullslime

    /// The asset release generation this species belongs to.
    ///
    /// This is intentionally independent from a player's completed journeys.
    /// Future species can return 2, 3, and so on as new asset generations ship.
    public var contentGeneration: Int {
        switch self {
        case .bytebot, .cachecat, .stackfox, .promptpup, .nullslime:
            1
        }
    }

    public static var latestContentGeneration: Int {
        Self.allCases.map(\.contentGeneration).max() ?? 1
    }

    public static var totalRegisteredFormCount: Int {
        Self.allCases.count
            * CompanionRarity.allCases.count
            * CompanionGameStage.allCases.filter { $0 != .egg }.count
    }

    /// The player-facing collection target. Lifecycle sprites belong to a
    /// journey album and do not inflate the number of companions to discover.
    public static var totalCollectibleVariantCount: Int {
        Self.allCases.count * CompanionVariantRegistry.collectibleIDs.count
    }
}
