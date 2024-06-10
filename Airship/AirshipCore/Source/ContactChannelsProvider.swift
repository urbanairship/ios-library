/* Copyright Airship and Contributors */

import Foundation
import Combine

/**
 * Contact channels provider protocol for receiving contact updates.
 * @note For internal use only. :nodoc:
 */
protocol ContactChannelsProviderProtocol: AnyActor {
    func contactChannels(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<ContactChannelsResult>
}

/// Provides a stream of contact updates at a regular interval
final actor ContactChannelsProvider: ContactChannelsProviderProtocol {
    private let audienceOverrides: AudienceOverridesProvider
    private let apiClient: ContactChannelsAPIClientProtocol
    private let maxChannelListCacheAge: TimeInterval
    private let overridesApplier: OverridesApplier = OverridesApplier()
    private let taskSleeper: AirshipTaskSleeper
    private let privacyManager: AirshipPrivacyManager
    private var resolvers: [String: Resolver] = [:]
    private let date: AirshipDateProtocol

    init(
        audienceOverrides: AudienceOverridesProvider,
        apiClient: ContactChannelsAPIClientProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared,
        maxChannelListCacheAgeSeconds: TimeInterval = 600,
        privacyManager: AirshipPrivacyManager
    ) {
        self.audienceOverrides = audienceOverrides
        self.apiClient = apiClient
        self.taskSleeper = taskSleeper
        self.maxChannelListCacheAge = maxChannelListCacheAgeSeconds
        self.privacyManager = privacyManager
        self.date = date
    }

    private func getResolver(contactID: String, lastContactID: String?) -> Resolver {
        // The resolver for the lastContactID can always be dropped, but we
        // can't assume the contactID is the current stable contact ID since
        // its an async stream and we might not be on the last element.
        
        if let lastContactID {
            resolvers[lastContactID] = nil
        }

        if let resolver = resolvers[contactID] {
            return resolver
        }

        let resolver = Resolver(
            contactID: contactID,
            audienceOverrides: audienceOverrides,
            apiClient: apiClient,
            maxChannelListCacheAge: maxChannelListCacheAge,
            taskSleeper: taskSleeper,
            overridesApplier: overridesApplier,
            privacyManager: privacyManager,
            date: self.date
        )

        resolvers[contactID] = resolver

        return resolver
    }

    /// Returns the latest contact channel result stream from the latest stable contact ID
    nonisolated func contactChannels(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<ContactChannelsResult> {
        return AsyncStream { continuation in
            let fetchTask = Task { [weak self] in
                var resolverTask: Task<Void, Never>?
                var lastContactID: String? = nil
                for await contactID in stableContactIDUpdates {
                    resolverTask?.cancel()
                    guard !Task.isCancelled else { return }

                    guard 
                        let resolver = await self?.getResolver(
                            contactID: contactID,
                            lastContactID: lastContactID
                        )
                    else {
                        return
                    }

                    resolverTask = Task {
                        for await update in await resolver.contactUpdates() {
                            guard !Task.isCancelled else { return }
                            continuation.yield(update)
                        }
                    }

                    lastContactID  = contactID
                }
            }

            continuation.onTermination = { _ in
                fetchTask.cancel()
            }
        }
    }

    /// Manages the contact update API calls including backoff and override application
    fileprivate actor Resolver {
        private let contactID: String
        private let audienceOverrides: AudienceOverridesProvider
        private let apiClient: ContactChannelsAPIClientProtocol
        private let cachedChannelsList: CachedValue<[ContactChannel]>
        private let fetchQueue: AirshipSerialQueue = AirshipSerialQueue()
        private let maxChannelListCacheAge: TimeInterval
        private let taskSleeper: AirshipTaskSleeper
        private let overridesApplier: OverridesApplier
        private let privacyManager: AirshipPrivacyManager

        private static let initialBackoff: TimeInterval = 8.0
        private static let maxBackoff: TimeInterval = 64.0
        private var lastResults: [String: ContactChannelsResult] = [:]

        init(
            contactID: String,
            audienceOverrides: AudienceOverridesProvider,
            apiClient: ContactChannelsAPIClientProtocol,
            maxChannelListCacheAge: TimeInterval,
            taskSleeper: AirshipTaskSleeper,
            overridesApplier: OverridesApplier,
            privacyManager: AirshipPrivacyManager,
            date: AirshipDateProtocol
        ) {
            self.contactID = contactID
            self.audienceOverrides = audienceOverrides
            self.apiClient = apiClient
            self.maxChannelListCacheAge = maxChannelListCacheAge
            self.taskSleeper = taskSleeper
            self.overridesApplier = overridesApplier
            self.privacyManager = privacyManager
            self.cachedChannelsList = CachedValue(date: date)
        }

        func contactUpdates() -> AsyncStream<ContactChannelsResult> {
            let id = UUID().uuidString

            return AsyncStream { continuation in
                let refreshTask = Task {
                    var backoff = Self.initialBackoff

                    repeat {
                        let fetched = await self.fetch()
                        let workingResult: ContactChannelsResult = if fetched.isSuccess {
                            fetched
                        } else if let lastResult = lastResults[id], lastResult.isSuccess {
                            lastResult
                        } else {
                            fetched
                        }

                        guard !Task.isCancelled else { return }

                        let overrideUpdates = await self.audienceOverrides.contactOverrideUpdates(
                            contactID: contactID
                        )

                        let updateTask = Task {
                            for await overrides in overrideUpdates {
                                guard !Task.isCancelled else {
                                    return
                                }

                                let result = await overridesApplier.applyUpdates(
                                    result: workingResult,
                                    overrides: overrides
                                )

                                if (lastResults[id] != result) {
                                    continuation.yield(result)
                                    lastResults[id] = result
                                }
                            }
                        }

                        if (fetched.isSuccess) {
                            try await self.taskSleeper.sleep(
                                timeInterval: cachedChannelsList.timeRemaining
                            )
                            backoff = Self.initialBackoff
                        } else {
                            try await self.taskSleeper.sleep(
                                timeInterval: backoff
                            )
                            if backoff < Self.maxBackoff {
                                backoff = backoff * 2
                            }
                        }

                        updateTask.cancel()
                    } while (!Task.isCancelled)
                }

                continuation.onTermination = { _ in
                    refreshTask.cancel()
                }
            }
        }

        private func fetch() async -> ContactChannelsResult {
            guard privacyManager.isEnabled(.contacts) else {
                return .error(.contactsDisabled)
            }

            return await self.fetchQueue.runSafe { [cachedChannelsList, apiClient, contactID, maxChannelListCacheAge] in
                if let cached = cachedChannelsList.value {
                    return .success(cached)
                }

                do {
                    let response = try await apiClient.fetchAssociatedChannelsList(
                        contactID: contactID
                    )

                    guard response.isSuccess, let list = response.result else {
                        throw AirshipErrors.error("Failed to fetch associated channels list")
                    }

                    cachedChannelsList.set(
                        value: list,
                        expiresIn: maxChannelListCacheAge
                    )
                    return .success(list)
                } catch {
                    AirshipLogger.warn(
                        "Received error when fetching contact channels \(error))"
                    )

                    return .error(.failedToFetchContacts)
                }
            }
        }
    }
}

public enum ContactChannelErrors: Error, Equatable, Sendable, Hashable {
    case contactsDisabled
    case failedToFetchContacts
}

public enum ContactChannelsResult: Equatable, Sendable, Hashable {
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
            if case .associated(let contactChannel, let channelID) = update {
                if let address = contactChannel.canonicalAddress, let channelID {
                    addressToChannelIDMap[address] = channelID
                }
            }
        }

        for update in overrides.channels {
            switch (update) {
            case .disassociated(let channel):
                mutated.removeAll {
                    isMatch(channel: $0, otherChannel: channel)
                }

            case .associated(let channel, let registeredChannelID):
                let found = mutated.contains(
                    where: {
                        isMatch(
                            channel: $0,
                            otherChannel: channel,
                            otherChannelID: registeredChannelID
                        )
                    }
                )

                if (!found) {
                    mutated.append(channel)
                }
            }
        }

        return .success(mutated)
    }

    private func isMatch(
        channel: ContactChannel,
        otherChannel: ContactChannel,
        otherChannelID: String? = nil
    ) -> Bool {
        let canonicalAddress = channel.canonicalAddress
        let resolvedChannelID = resolveChannelID(contactChannel: channel, canonicalAddress: canonicalAddress)

        let otherCanonicalAddress = otherChannel.canonicalAddress
        let otherResolvedChannelID = otherChannelID ?? resolveChannelID(contactChannel: otherChannel, canonicalAddress: otherCanonicalAddress)

        if let resolvedChannelID, resolvedChannelID == otherResolvedChannelID {
            return true
        }

        if let canonicalAddress, canonicalAddress == otherCanonicalAddress {
            return true
        }

        return false
    }

    private func resolveChannelID(contactChannel: ContactChannel, canonicalAddress: String?) -> String? {
        if let channelID = contactChannel.channelID {
            return channelID
        }

        if let canonicalAddress {
            return addressToChannelIDMap[canonicalAddress]
        }

        return nil
    }
}



fileprivate extension ContactChannel.PendingRegistration {
    var canonicalAddress: String {
        if case let .sms(options) = self.pendingRegistrationInfo {
            return self.address + ":" + options.senderID
        }
        return self.address
    }
}

internal extension ContactChannel {
    var channelID: String? {
        switch (self) {
        case .pending(_): return nil
        case .registered(let registered): return registered.channelID
        }
    }

    var canonicalAddress: String? {
        switch (self) {
        case .pending(let pending): return pending.canonicalAddress
        case .registered(_): return nil
        }
    }

    var isPending: Bool {
        switch (self) {
        case .pending(_): return true
        case .registered(_): return false
        }
    }
}

