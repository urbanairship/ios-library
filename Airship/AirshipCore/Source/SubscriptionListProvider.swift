/* Copyright Airship and Contributors */

import Foundation
import Combine

/**
 * Subscription list provider protocol for receiving contact updates.
 * @note For internal use only. :nodoc:
 */
protocol SubscriptionListProviderProtocol: Sendable {
    func subscriptionList(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<SubscriptionListResult>
    func fetch(contactID: String) async throws -> [String: [ChannelScope]]
    func refresh() async
}

final class SubscriptionListProvider: SubscriptionListProviderProtocol {

    private let actor: BaseCachingRemoteDataProvider<SubscriptionListResult, ContactAudienceOverrides>
    
    init(
        audienceOverrides: any AudienceOverridesProvider,
        apiClient: any ContactSubscriptionListAPIClientProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = .shared,
        maxChannelListCacheAgeSeconds: TimeInterval = 600,
        privacyManager: any PrivacyManagerProtocol
    ) {
        
        self.actor = BaseCachingRemoteDataProvider(
            remoteFetcher: { contactID in
                return try await apiClient
                    .fetchSubscriptionLists(contactID: contactID)
                    .map(onMap: { response in
                        guard let result = response.result else {
                            return nil
                        }
                        
                        return .success(result)
                    })
            },
            overridesProvider: { identifier in
                return await audienceOverrides.contactOverrideUpdates(contactID: identifier)
            },
            overridesApplier: { result, overrides in
                guard
                    case .success(let list) = result
                else {
                    return result
                }
                
                let updated = AudienceUtils.applySubscriptionListsUpdates(list, updates: overrides.subscriptionLists)
                return .success(updated)
            },
            isEnabled: { privacyManager.isEnabled(.contacts) },
            date: date,
            taskSleeper: taskSleeper,
            cacheTtl: maxChannelListCacheAgeSeconds
        )
    }
    
    func subscriptionList(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<SubscriptionListResult> {
        return actor.updates(identifierUpdates: stableContactIDUpdates)
    }
    
    func refresh() async {
        await actor.refresh()
    }
    
    func fetch(contactID: String) async throws -> [String: [ChannelScope]] {
        var stream = actor.updates(identifierUpdates: AsyncStream { continuation in
            continuation.yield(contactID)
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

enum SubscriptionListResult: Equatable, Sendable, Hashable, CachingRemoteDataProviderResult {
    static func error(_ error: CachingRemoteDataError) -> any CachingRemoteDataProviderResult {
        return SubscriptionListResult.fail(error)
    }
    
    case success([String: [ChannelScope]])
    case fail(CachingRemoteDataError)

    public var subscriptionList: [String: [ChannelScope]] {
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
