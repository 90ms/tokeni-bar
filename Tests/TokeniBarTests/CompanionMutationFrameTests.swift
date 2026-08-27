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
                        #expect(self.alphaBytes(in: mutatedBytes)
                            == self.alphaBytes(in: standardBytes))
                        #expect(self.allIntroducedPixelsAttachToStandard(
                            standard: standardBytes,
                            mutated: mutatedBytes,
                            width: standard.width,
                            height: standard.height))
                    }
                }
            }
        }
    }

    private func rgbaBytes(of image: CGImage) throws -> Data {
        let bytesPerRow = image.width * 4
        let context = try #require(CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data)
        return Data(bytes: bytes, count: bytesPerRow * image.height)
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

    private func alphaBytes(in bytes: Data) -> [UInt8] {
        stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
    }

    private func allIntroducedPixelsAttachToStandard(
        standard: Data,
        mutated: Data,
        width: Int,
        height: Int) -> Bool
    {
        guard standard.count == mutated.count,
              standard.count >= width * height * 4
        else { return false }
        let standardOpaque = (0..<(width * height)).map {
            standard[$0 * 4 + 3] > 0
        }
        let introduced = (0..<(width * height)).map {
            !standardOpaque[$0] && mutated[$0 * 4 + 3] > 0
        }
        var visited = Array(repeating: false, count: width * height)

        for start in 0..<(width * height) where introduced[start] && !visited[start] {
            var stack = [start]
            var touchesStandard = false
            visited[start] = true
            while let index = stack.popLast() {
                let x = index % width
                let y = index / width
                let neighbors = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < width ? index + 1 : -1,
                    y > 0 ? index - width : -1,
                    y + 1 < height ? index + width : -1,
                ]
                for neighbor in neighbors where neighbor >= 0 {
                    if standardOpaque[neighbor] {
                        touchesStandard = true
                    } else if introduced[neighbor], !visited[neighbor] {
                        visited[neighbor] = true
                        stack.append(neighbor)
                    }
                }
            }
            if !touchesStandard { return false }
        }
        return true
    }
}
