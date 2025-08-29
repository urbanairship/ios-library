/* Copyright Airship and Contributors */

import Foundation
import Combine

/**
 * Subscription list provider protocol for receiving contact updates.
 * @note For internal use only. :nodoc:
 */
protocol ChannelSubscriptionListProviderProtocol: Sendable {
    func fetch(channelID: String) async throws -> [String]
}

final class ChannelSubscriptionListProvider: ChannelSubscriptionListProviderProtocol {

    private let actor: BaseCachingRemoteDataProvider<ChannelSubscriptionListResult, ChannelAudienceOverrides>
    private let overridesApplier = OverridesApplier()
    
    init(
        audienceOverrides: any AudienceOverridesProvider,
        apiClient: any SubscriptionListAPIClientProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = .shared,
        maxChannelListCacheAgeSeconds: TimeInterval = 600
    ) {
        
        self.actor = BaseCachingRemoteDataProvider(
            remoteFetcher: { channelID in
                return try await apiClient
                    .get(channelID: channelID)
                    .map(onMap: { response in
                        guard let result = response.result else {
                            return nil
                        }
                        
                        return .success(result)
                    })
            },
            overridesProvider: { channelID in
                return AsyncStream { continuation in
                    Task {
                        let override = await audienceOverrides.channelOverrides(channelID: channelID)
                        continuation.yield(override)
                        continuation.finish()
                    }
                }
            },
            overridesApplier: { [overridesApplier] result, overrides in
                guard
                    case .success(let list) = result
                else {
                    return result
                }
                
                return .success(overridesApplier.applySubscriptionListUpdates(list, updates: overrides.subscriptionLists))
            },
            isEnabled: { true },
            date: date,
            taskSleeper: taskSleeper,
            cacheTtl: maxChannelListCacheAgeSeconds
        )
    }
    
    
    func fetch(channelID: String) async throws -> [String] {
        var stream = actor.updates(identifierUpdates: AsyncStream { continuation in
            continuation.yield(channelID)
            continuation.finish()
        })
            .makeAsyncIterator()
        
        guard let result = await stream.next() else {
            throw AirshipErrors.error("Failed to get subscription list")
        }
        
        switch result {
        case .fail(let error): throw error
        case .success(let list): return list
        }
    }
}

enum ChannelSubscriptionListResult: Equatable, Sendable, Hashable, CachingRemoteDataProviderResult {
    static func error(_ error: CachingRemoteDataError) -> any CachingRemoteDataProviderResult {
        return ChannelSubscriptionListResult.fail(error)
    }
    
    case success([String])
    case fail(CachingRemoteDataError)

    public var subscriptionList: [String] {
        get throws {
            switch(self) {
            case .fail(let error): throw error
            case .success(let list): return list
            }
        }
    }

    public var isSuccess: Bool {
        switch(self) {
        case .fail(_): return false
        case .success(_): return true
        }
    }
}

private struct OverridesApplier {
    
    func applySubscriptionListUpdates(
        _ ids: [String],
        updates: [SubscriptionListUpdate]
    ) -> [String] {
        guard !updates.isEmpty else {
            return ids
        }

        var result = ids
        updates.forEach { update in
            switch update.type {
            case .subscribe:
                if !result.contains(update.listId) {
                    result.append(update.listId)
                }
            case .unsubscribe:
                result.removeAll(where: { $0 == update.listId })
            }
        }

        return result
    }
}
