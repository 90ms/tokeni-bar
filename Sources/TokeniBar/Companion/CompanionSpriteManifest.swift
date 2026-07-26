import Foundation
import TokeniCore

struct CompanionSpriteManifest: Decodable {
    struct Animation: Decodable {
        let row: Int
        let frameCount: Int
        let framesPerSecond: Double
        let loops: Bool
    }

    let schemaVersion: Int
    let id: String
    let displayName: String
    let logicalFrameSize: Int
    let columns: Int
    let rows: Int
    let palette: [String]
    let forms: [String: String]
    let animations: [String: Animation]

    func sheetName(
        for stage: CompanionGameStage,
        rarity requestedRarity: CompanionRarity) -> String?
    {
        let rarity = stage == .egg ? CompanionRarity.normal : requestedRarity
        let key = "\(stage.rawValue).\(rarity.rawValue)"
        return self.forms[key]
            ?? self.forms["\(stage.rawValue).\(CompanionRarity.normal.rawValue)"]
    }

    func animation(for behavior: CompanionBehavior) -> Animation? {
        self.animations[behavior.rawValue]
    }
}
