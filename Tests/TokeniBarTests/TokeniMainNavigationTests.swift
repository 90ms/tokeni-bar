import Testing
@testable import TokeniBar

struct TokeniMainNavigationTests {
    @Test("Main navigation has one stable destination per product area")
    func destinationsAreStableAndUnique() {
        #expect(TokeniMainDestination.allCases == [
            .home,
            .usage,
            .pets,
            .settings,
        ])
        #expect(Set(TokeniMainDestination.allCases.map(\.rawValue)).count == 4)
        #expect(Set(TokeniMainDestination.allCases.map(\.localizationKey)).count == 4)
        #expect(Set(TokeniMainDestination.allCases.map(\.systemImage)).count == 4)
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
