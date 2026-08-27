import AppKit
import Testing
@testable import TokeniBar

@MainActor
struct CompanionRasterSymbolTests {
    @Test("Animated companion symbols reuse one raster image")
    func rasterSymbolsAreCached() throws {
        let first = try #require(CompanionRasterSymbolCache.image(named: "sparkle"))
        let second = try #require(CompanionRasterSymbolCache.image(named: "sparkle"))

        #expect(first === second)
        #expect(first.representations.contains { $0 is NSBitmapImageRep })
        #expect(first.isTemplate)
    }
}
