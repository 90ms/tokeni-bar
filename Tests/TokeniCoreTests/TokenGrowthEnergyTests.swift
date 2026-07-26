import Foundation
import Testing
@testable import TokeniCore

@Suite("Token growth energy")
struct TokenGrowthEnergyTests {
    @Test("Matches the published standard curve")
    func standardCurve() {
        let formula = TokenGrowthEnergyFormula.standard

        #expect(formula.energy(forDailyTokens: 0) == 0)
        #expect(formula.energy(forDailyTokens: 10_000) == 15)
        #expect(formula.energy(forDailyTokens: 25_000) == 32)
        #expect(formula.energy(forDailyTokens: 50_000) == 50)
        #expect(formula.energy(forDailyTokens: 100_000) == 74)
        #expect(formula.energy(forDailyTokens: 250_000) == 110)
        #expect(formula.energy(forDailyTokens: 500_000) == 140)
        #expect(formula.energy(forDailyTokens: 1_000_000) == 171)
        #expect(formula.energy(forDailyTokens: 2_000_000) == 202)
    }

    @Test("Never decreases and has no hard cap")
    func monotonicAndUncapped() {
        let formula = TokenGrowthEnergyFormula.standard
        var previous = 0

        for tokens in stride(from: Int64(0), through: 10_000_000, by: 1_000) {
            let energy = formula.energy(forDailyTokens: tokens)
            #expect(energy >= previous)
            previous = energy
        }

        #expect(formula.energy(forDailyTokens: 10_000_000)
            > formula.energy(forDailyTokens: 1_000_000))
    }

    @Test("Local date keys honor the supplied time zone")
    func localDateKey() throws {
        let date = try #require(ISO8601DateFormatter().date(
            from: "2026-07-26T16:30:00Z"))
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        #expect(GrowthLocalDate.key(for: date, calendar: seoul) == "2026-07-27")
        #expect(GrowthLocalDate.key(for: date, calendar: losAngeles) == "2026-07-26")
    }
}
