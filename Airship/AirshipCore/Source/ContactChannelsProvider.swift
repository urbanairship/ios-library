/* Copyright Airship and Contributors */

import Foundation

protocol ContactChannelsProviderProtocol: AnyActor {
    func contactUpdates(contactID: String) async throws -> AsyncStream<[ContactChannel]>
}

final actor ContactChannelsProvider: ContactChannelsProviderProtocol {
    private let audienceOverrides: AudienceOverridesProvider
    private let apiClient: ContactChannelsAPIClientProtocol
    private let cachedChannelsList: CachedValue<(String, [ContactChannel])>
    private let fetchQueue: AirshipSerialQueue = AirshipSerialQueue()
    private static let maxChannelListCacheAge: TimeInterval = 600

    private let taskSleeper: AirshipTaskSleeper

    init(
        audienceOverrides: AudienceOverridesProvider,
        apiClient: ContactChannelsAPIClientProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared
    ) {
        self.audienceOverrides = audienceOverrides
        self.apiClient = apiClient
        self.cachedChannelsList = CachedValue(date: date)
        self.taskSleeper = taskSleeper
    }

    func contactUpdates(contactID: String) async throws -> AsyncStream<[ContactChannel]> {
        let overrideUpdates = await self.audienceOverrides.contactOverrideUpdates(contactID: contactID)
        let fetched = try await self.resolveChannelsList(contactID)
        let initialHistory = await self.audienceOverrides.contactOverrides(contactID: contactID)
        let initial = fetched.applyUpdates(initialHistory.channels)

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            continuation.yield(initial)
            let refreshTask = Task {
                var initial = initial
                var overrideUpdates = overrideUpdates

                repeat {
                    let updateTask = Task { [initial, overrideUpdates] in
                        var workingSet = initial
                        for await overrides in overrideUpdates {
                            guard !Task.isCancelled else {
                                return
                            }
                            workingSet = workingSet.applyUpdates(overrides.channels)
                            continuation.yield(workingSet)
                        }
                    }

                    try await self.taskSleeper.sleep(timeInterval: Self.maxChannelListCacheAge)

                    overrideUpdates = await self.audienceOverrides.contactOverrideUpdates(contactID: contactID)

                    let fetched = try await self.resolveChannelsList(contactID)
                    updateTask.cancel()

                    let initialHistory = await self.audienceOverrides.contactOverrides(contactID: contactID)
                    initial = fetched.applyUpdates(initialHistory.channels)
                    continuation.yield(initial)
                } while (!Task.isCancelled)
            }

            continuation.onTermination = { _ in
                refreshTask.cancel()
            }
        }
    }

    private func resolveChannelsList(
        _ contactID: String
    ) async throws -> [ContactChannel] {
        return try await self.fetchQueue.run {
            if let cached = self.cachedChannelsList.value,
                cached.0 == contactID {
                return cached.1
            }

            let response = try await self.apiClient.fetchAssociatedChannelsList(
                contactID: contactID
            )

            guard response.isSuccess, let list = response.result else {
                throw AirshipErrors.error("Failed to fetch associated channels list")
            }

            self.cachedChannelsList.set(
                value: (contactID, list),
                expiresIn: Self.maxChannelListCacheAge
            )

            return list
        }
    }
}


extension Array where Element == ContactChannel {
    func applyUpdates(_ updates: [ContactChannelUpdate]?) -> [ContactChannel] {
        guard let updates else { return self }
        var mutated = self

        for update in updates {
            switch (update) {
            case .disassociated(let contact):
                mutated.removeAll {
                    let channelID = $0.channelID
                    let canonicalAddress = $0.canonicalAddress

                    if let canonicalAddress, contact.canonicalAddress == canonicalAddress {
                        return true
                    }

                    if let channelID, contact.channelID == channelID {
                        return true
                    }

                    return false
                }

            case .associated(let contact, let registeredChannelID):
                mutated.removeAll {
                    let channelID = $0.channelID
                    let canonicalAddress = $0.canonicalAddress

                    if let canonicalAddress, contact.canonicalAddress == canonicalAddress {
                        return true
                    }

                    if let channelID, registeredChannelID == channelID {
                        return true
                    }

                    return false
                }

                mutated.append(contact)
            }
        }

    
        return mutated
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
fileprivate extension ContactChannel {
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

