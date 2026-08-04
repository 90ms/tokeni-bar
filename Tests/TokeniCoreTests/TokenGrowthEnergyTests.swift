import Foundation
import Testing
@testable import TokeniCore

@Suite("Token growth energy")
struct TokenGrowthEnergyTests {
    @Test("Matches the published linear conversion")
    func standardConversion() {
        let formula = TokenGrowthEnergyFormula.standard

        #expect(formula.energy(forDailyTokens: 0) == 0)
        #expect(formula.energy(forDailyTokens: 49_999) == 0)
        #expect(formula.energy(forDailyTokens: 25_000) == 1)
        #expect(formula.energy(forDailyTokens: 250_000) == 10)
        #expect(formula.energy(forDailyTokens: 1_000_000) == 20)
        #expect(formula.energy(forDailyTokens: 300_000_000) == 6_000)
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

    @Test("Finds the exact next energy boundary")
    func nextEnergyBoundary() throws {
        let formula = TokenGrowthEnergyFormula.standard

        for tokens: Int64 in [0, 10_000, 25_000, 100_000, 2_000_000] {
            let currentEnergy = formula.energy(forDailyTokens: tokens)
            let additional = try #require(
                formula.additionalTokensForNextEnergy(afterDailyTokens: tokens))
            let threshold = tokens + additional

            #expect(additional > 0)
            #expect(formula.energy(forDailyTokens: threshold) == currentEnergy + 1)
            #expect(formula.energy(forDailyTokens: threshold - 1) == currentEnergy)
            #expect(formula.minimumDailyTokens(forEnergy: currentEnergy + 1) == threshold)
        }
    }

    @Test("Reports unreachable targets without overflowing")
    func unreachableTarget() {
        let disabled = TokenGrowthEnergyFormula(tokensPerEnergy: 0)

        #expect(disabled.minimumDailyTokens(forEnergy: 1) == nil)
        #expect(disabled.additionalTokensForNextEnergy(afterDailyTokens: 100_000) == nil)
        #expect(TokenGrowthEnergyFormula.standard.minimumDailyTokens(forEnergy: 0) == 0)
        #expect(TokenGrowthEnergyFormula.standard.minimumDailyTokens(forEnergy: -1) == 0)
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
