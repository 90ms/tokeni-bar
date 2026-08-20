import Foundation
import TokeniCore

public struct UsageRefreshResult: Equatable, Sendable {
    public let snapshots: [ProviderSnapshot]
    public let refreshedAt: Date

    public init(snapshots: [ProviderSnapshot], refreshedAt: Date) {
        self.snapshots = snapshots
        self.refreshedAt = refreshedAt
    }
}

public actor UsageRefreshCoordinator {
    private let providers: [any UsageProviding]

    public init(providers: [any UsageProviding]) {
        self.providers = providers
    }

    public func refresh(
        enabledProviderIDs: Set<ProviderID>,
        forceProviderReload: Bool = false,
        now: Date = .now) async -> UsageRefreshResult
    {
        let activeProviders = self.providers.filter {
            enabledProviderIDs.contains($0.descriptor.id)
        }

        if forceProviderReload {
            for provider in activeProviders {
                guard let cacheInvalidating = provider as? any UsageCacheInvalidating
                else { continue }
                await cacheInvalidating.invalidateUsageCache()
            }
        }

        let results = await withTaskGroup(
            of: ProviderSnapshot.self,
            returning: [ProviderSnapshot].self)
        { group in
            for provider in activeProviders {
                group.addTask { await provider.fetchUsage() }
            }

            var collected: [ProviderSnapshot] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        let order = Dictionary(uniqueKeysWithValues: activeProviders.enumerated().map {
            ($1.descriptor.id, $0)
        })
        let orderedResults = results.sorted {
            order[$0.id, default: .max] < order[$1.id, default: .max]
        }

        return UsageRefreshResult(
            snapshots: orderedResults,
            refreshedAt: now)
    }
}
