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
                        let changedPixelCount = self.changedPixelCount(
                            standard: standardBytes,
                            mutated: mutatedBytes)
                        let standardPixelCount = self.opaquePixelCount(standardBytes)

                        #expect(changedPixelCount > 0)
                        #expect(changedPixelCount <= max(standardPixelCount / 5, 12))
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

    private func changedPixelCount(
        standard: Data,
        mutated: Data) -> Int
    {
        guard standard.count == mutated.count else { return 0 }
        var count = 0
        for pixelStart in stride(from: 0, to: standard.count, by: 4) {
            let pixelEnd = min(pixelStart + 4, standard.count)
            if standard[pixelStart..<pixelEnd] != mutated[pixelStart..<pixelEnd] {
                count += 1
            }
        }
        return count
    }

    private func opaquePixelCount(_ bytes: Data) -> Int {
        stride(from: 3, to: bytes.count, by: 4).reduce(into: 0) {
            count, alphaIndex in
            if bytes[alphaIndex] > 0 {
                count += 1
            }
        }
    }
}
