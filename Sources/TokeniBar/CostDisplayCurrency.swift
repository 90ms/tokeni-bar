import TokeniCore
import Foundation

enum CostDisplayCurrency: String, CaseIterable, Identifiable {
    case usd
    case krw

    var id: String { self.rawValue }

    static var defaultValue: Self {
        Locale.current.currency?.identifier == "KRW" ? .krw : .usd
    }

    func amount(fromUSD amountUSD: Double, exchangeRate: ExchangeRateQuote?) -> Double? {
        switch self {
        case .usd: amountUSD
        case .krw: exchangeRate.map { amountUSD * $0.rate }
        }
    }

    func usdAmount(from amount: Double, exchangeRate: ExchangeRateQuote?) -> Double? {
        switch self {
        case .usd: return amount
        case .krw:
            guard let exchangeRate, exchangeRate.rate > 0 else { return nil }
            return amount / exchangeRate.rate
        }
    }

    func formatted(amountUSD: Double, exchangeRate: ExchangeRateQuote?) -> String? {
        guard let amount = self.amount(fromUSD: amountUSD, exchangeRate: exchangeRate) else {
            return nil
        }
        switch self {
        case .usd:
            let digits = amount < 0.01 ? 4 : 2
            return "$" + amount.formatted(.number.precision(.fractionLength(digits)))
        case .krw:
            let digits = amount < 1 ? 2 : 0
            return "₩" + amount.formatted(.number.precision(.fractionLength(digits)))
        }
    }
}
