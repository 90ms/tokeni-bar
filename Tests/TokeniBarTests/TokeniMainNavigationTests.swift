import Testing
@testable import TokeniBar

struct TokeniMainNavigationTests {
    @Test("Main navigation has one stable destination per product area")
    func destinationsAreStableAndUnique() {
        #expect(TokeniMainDestination.allCases == [
            .home,
            .pets,
            .usage,
            .settings,
        ])
        #expect(Set(TokeniMainDestination.allCases.map(\.rawValue)).count == 4)
        #expect(Set(TokeniMainDestination.allCases.map(\.localizationKey)).count == 4)
        #expect(Set(TokeniMainDestination.allCases.map(\.systemImage)).count == 4)
    }
}
