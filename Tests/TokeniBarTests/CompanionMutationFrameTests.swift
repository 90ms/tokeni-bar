import CoreGraphics
import Foundation
import Testing
@testable import TokeniBar
import TokeniCore

@MainActor
struct CompanionMutationFrameTests {
    @Test("Every Mutation animation frame derives a visible intrinsic body trait")
    func allMutationFramesDifferFromStandard() throws {
        let catalog = CompanionAssetCatalog.shared
        let stages: [CompanionGameStage] = [.hatchling, .junior, .adult]

        for speciesID in CompanionSpeciesID.allCases {
            for stage in stages {
                for behavior in CompanionBehavior.allCases {
                    let animation = try #require(catalog.animation(
                        for: speciesID,
                        behavior: behavior))
                    for index in 0..<animation.frameCount {
                        let standard = try #require(catalog.frame(
                            speciesID: speciesID,
                            stage: stage,
                            rarity: .normal,
                            variantID: .standard,
                            behavior: behavior,
                            index: index))
                        let mutated = try #require(catalog.frame(
                            speciesID: speciesID,
                            stage: stage,
                            rarity: .normal,
                            variantID: .mutated,
                            behavior: behavior,
                            index: index))
                        let standardBytes = try self.rgbaBytes(of: standard)
                        let mutatedBytes = try self.rgbaBytes(of: mutated)

                        #expect(mutatedBytes != standardBytes)
                        #expect(self.addedOpaquePixelCount(
                            standard: standardBytes,
                            mutated: mutatedBytes) > 0)
                    }
                }
            }
        }
    }

    private func rgbaBytes(of image: CGImage) throws -> Data {
        let provider = try #require(image.dataProvider)
        let data = try #require(provider.data)
        return data as Data
    }

    private func addedOpaquePixelCount(
        standard: Data,
        mutated: Data) -> Int
    {
        guard standard.count == mutated.count else { return 0 }
        var count = 0
        for alphaIndex in stride(from: 3, to: standard.count, by: 4)
        where standard[alphaIndex] == 0 && mutated[alphaIndex] > 0
        {
            count += 1
        }
        return count
    }
}
