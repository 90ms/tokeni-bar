import Foundation

public enum UsageCostSummary {
    public static func accumulatedUSD(
        in records: [UsageHistoryRecord],
        since startDate: Date,
        providerID: ProviderID? = nil) -> Double
    {
        let matching = records.filter { record in
            providerID.map { $0 == record.providerID } != false
        }
        let grouped = Dictionary(grouping: matching, by: \.providerID)
        return grouped.values.reduce(0) { total, providerRecords in
            total + self.accumulatedUSD(
                inSingleProvider: providerRecords,
                since: startDate)
        }
    }

    private static func accumulatedUSD(
        inSingleProvider records: [UsageHistoryRecord],
        since startDate: Date) -> Double
    {
        var previous: Double?
        var total = 0.0
        for record in records.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let cost = record.costUSD, cost >= 0 else { continue }
            if record.timestamp < startDate {
                previous = cost
                continue
            }
            if let previous {
                total += cost >= previous ? cost - previous : cost
            }
            // The first value is a baseline. Only changes observed afterward count as spend.
            previous = cost
        }
        return total
    }
}
