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
    let assetFrameSize: Int
    let columns: Int
    let rows: Int
    let palette: [String]
    let stages: [String: String]
    let animations: [String: Animation]

    func sheetName(for stage: CompanionGameStage) -> String? {
        if let sheet = self.stages[stage.rawValue] {
            return sheet
        }
        return stage == .junior ? self.stages["baby"] : nil
    }

    func animation(for behavior: CompanionBehavior) -> Animation? {
        self.animations[behavior.rawValue]
    }
}
