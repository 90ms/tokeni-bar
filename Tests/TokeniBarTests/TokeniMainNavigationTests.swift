import Testing
@testable import TokeniBar

struct TokeniMainNavigationTests {
    @Test("Main navigation has one stable destination per product area")
    func destinationsAreStableAndUnique() {
        #expect(TokeniMainDestination.allCases == [
            .home,
            .pets,
            .usage,
        ])
        #expect(Set(TokeniMainDestination.allCases.map(\.rawValue)).count == 3)
        #expect(Set(TokeniMainDestination.allCases.map(\.localizationKey)).count == 3)
        #expect(Set(TokeniMainDestination.allCases.map(\.systemImage)).count == 3)
    }

    @Test("Main navigation can route menu-bar actions to one destination")
    @MainActor
    func navigationSelectionIsShared() {
        let navigation = TokeniMainNavigation()
        #expect(navigation.destination == .home)

        navigation.select(.usage)
        #expect(navigation.destination == .usage)
    }
}
