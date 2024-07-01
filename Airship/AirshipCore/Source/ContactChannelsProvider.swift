/* Copyright Airship and Contributors */

import Foundation
import Combine

/**
 * Contact channels provider protocol for receiving contact updates.
 * @note For internal use only. :nodoc:
 */
protocol ContactChannelsProviderProtocol: Sendable {
    func contactChannels(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<ContactChannelsResult>
    func refresh() async
    func refreshAsync()
}

final class ContactChannelsProvider: ContactChannelsProviderProtocol {
    private let actor: BaseCachingRemoteDataProvider<ContactChannelsResult, ContactAudienceOverrides>
    private let overridesApplier: OverridesApplier = OverridesApplier()
    
    init(
        audienceOverrides: AudienceOverridesProvider,
        apiClient: ContactChannelsAPIClientProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared,
        maxChannelListCacheAgeSeconds: TimeInterval = 600,
        privacyManager: AirshipPrivacyManager
    ) {
        self.actor = BaseCachingRemoteDataProvider(
            remoteFetcher: { contactID in
                return try await apiClient
                    .fetchAssociatedChannelsList(contactID: contactID)
                    .map { response in
                        guard let result = response.result else {
                            return nil
                        }
                        return .success(result)
                    }
            }, 
            overridesProvider: { identifier in
                return await audienceOverrides.contactOverrideUpdates(contactID: identifier)
            },
            overridesApplier: { [overridesApplier] result, overrides in
                return await overridesApplier.applyUpdates(result: result, overrides: overrides)
            },
            isEnabled: { privacyManager.isEnabled(.contacts) },
            date: date,
            taskSleeper: taskSleeper,
            cacheTtl: maxChannelListCacheAgeSeconds
        )
    }
    
    /// Returns the latest contact channel result stream from the latest stable contact ID
    func contactChannels(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<ContactChannelsResult> {
        return actor.updates(identifierUpdates: stableContactIDUpdates)
    }
    
    func refresh() async {
        await actor.refresh()
    }

    func refreshAsync() {
        Task {
            await refresh()
        }
    }
}

public enum ContactChannelErrors: Error, Equatable, Sendable, Hashable {
    case contactsDisabled
    case failedToFetchContacts
}

fileprivate extension CachingRemoteDataError {
    func toChannelError() -> ContactChannelErrors {
        switch (self) {
        case .disabled: return .contactsDisabled
        case .failedToFetch: return .failedToFetchContacts
        }
    }
}

public enum ContactChannelsResult: Equatable, Sendable, Hashable, CachingRemoteDataProviderResult {
    static func error(_ error: CachingRemoteDataError) -> any CachingRemoteDataProviderResult {
        return ContactChannelsResult.error(error.toChannelError())
    }
    
    case success([ContactChannel])
    case error(ContactChannelErrors)

    public var channels: [ContactChannel] {
        get throws {
            switch(self) {
            case .error(let error): throw error
            case .success(let channels): return channels
            }
        }
    }

    public var isSuccess: Bool {
        switch(self) {
        case .error(_): return false
        case .success(_): return true
        }
    }
}


fileprivate actor OverridesApplier {
    private var addressToChannelIDMap: [String: String] = [:]

    func applyUpdates(result: ContactChannelsResult, overrides: ContactAudienceOverrides) -> ContactChannelsResult {
        guard
            case .success(let channels) = result,
            !overrides.channels.isEmpty
        else {
            return result
        }

        var mutated = channels

        overrides.channels.forEach { update in
            switch(update) {
            case .associated(let channel, let channelID):
                if let address = channel.canonicalAddress, let channelID {
                    self.addressToChannelIDMap[address] = channelID
                }
            case .disassociated(let channel, let channelID):
                if let address = channel.canonicalAddress, let channelID {
                    self.addressToChannelIDMap[address] = channelID
                }
            case .associatedAnonChannel(_, _):
                // no-op
                break
            }
        }

        for update in overrides.channels {
            switch(update) {
            case .associated(let channel, _):
                let found = mutated.contains(
                    where: {
                        isMatch(
                            channel: $0,
                            update: update
                        )
                    }
                )

                if (!found) {
                    mutated.append(channel)
                }


            case .disassociated(_, _):
                mutated.removeAll {
                    isMatch(
                        channel: $0,
                        update: update
                    )
                }
            case .associatedAnonChannel(_, _):
                // no-op
                break
            }
        }

        return .success(mutated)
    }

    private func isMatch(
        channel: ContactChannel,
        update: ContactChannelUpdate
    ) -> Bool {
        let canonicalAddress = channel.canonicalAddress
        let resolvedChannelID = resolveChannelID(
            channelID: channel.channelID,
            canonicalAddress: canonicalAddress
        )

        let updateCanonicalAddress = update.canonicalAddress
        let updateChannelID = resolveChannelID(
            channelID: update.channelID,
            canonicalAddress: updateCanonicalAddress
        )

        if let resolvedChannelID, resolvedChannelID == updateChannelID {
            return true
        }

        if let canonicalAddress, canonicalAddress == updateCanonicalAddress {
            return true
        }

        return false
    }

    private func resolveChannelID(
        channelID: String?,
        canonicalAddress: String?
    ) -> String? {
        if let channelID {
            return channelID
        }

        if let canonicalAddress {
            return addressToChannelIDMap[canonicalAddress]
        }

        return nil
    }
}


extension ContactChannelUpdate {
    var canonicalAddress: String? {
        switch (self) {
        case .associated(let channel, _): return channel.canonicalAddress
        case .disassociated(let channel, _): return channel.canonicalAddress
        case .associatedAnonChannel(_, _): return nil
        }
    }

    var channelID: String? {
        switch (self) {
        case .associated(let channel, let channelID): return channelID ?? channel.channelID
        case .disassociated(let channel, let channelID): return channelID ?? channel.channelID
        case .associatedAnonChannel(_, let channelID): return channelID
        }
    }
}

extension ContactChannel {
    var channelID: String? {
        switch (self) {
        case .email(let email):
            switch(email) {
            case .pending(_): return nil
            case .registered(let info): return info.channelID
            }
        case .sms(let sms):
            switch(sms) {
            case .pending(_): return nil
            case .registered(let info): return info.channelID
            }
        }
    }

    var canonicalAddress: String? {
        switch (self) {
        case .email(let email):
            switch(email) {
            case .pending(let info): return info.address
            case .registered(_): return nil
            }
        case .sms(let sms):
            switch(sms) {
            case .pending(let info): return "(\(info.address):\(info.registrationOptions.senderID)"
            case .registered(_): return nil
            }
        }
    }
}

