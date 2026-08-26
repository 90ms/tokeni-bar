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
        variantID: CompanionVariantID,
        fallbackRarity: CompanionRarity) -> String?
    {
        if stage != .egg,
           let variantSheet = self.forms[
               "\(stage.rawValue).\(variantID.rawValue)"]
        {
            return variantSheet
        }
        let rarity: CompanionRarity = if stage == .egg {
            .normal
        } else {
            switch variantID {
            case .standard, .mutated: .normal
            case .prismatic: .legendary
            default: fallbackRarity
            }
        }
        let key = "\(stage.rawValue).\(rarity.rawValue)"
        return self.forms[key]
            ?? self.forms["\(stage.rawValue).\(CompanionRarity.normal.rawValue)"]
    }

    func animation(for behavior: CompanionBehavior) -> Animation? {
        self.animations[behavior.rawValue]
    }
}
