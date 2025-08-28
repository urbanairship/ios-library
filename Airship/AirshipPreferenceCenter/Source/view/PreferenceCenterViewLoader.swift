/* Copyright Airship and Contributors */

import Combine

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class PreferenceCenterViewLoader: ObservableObject {

    @Published
    public private(set) var phase: PreferenceCenterViewPhase = .loading

    private var task: Task<Void, Never>?

    public func load(
        preferenceCenterID: String,
        onLoad: (@Sendable (String) async -> PreferenceCenterViewPhase)? = nil
    ) {
        self.task?.cancel()
        self.task = Task { @MainActor in
            await loadAsync(
                preferenceCenterID: preferenceCenterID,
                onLoad: onLoad
            )
        }
    }

    @MainActor
    private func loadAsync(
        preferenceCenterID: String,
        onLoad: (@Sendable @MainActor (String) async -> PreferenceCenterViewPhase)? = nil
    ) async {
        self.phase = .loading

        if let onLoad = onLoad {
            self.phase = await onLoad(preferenceCenterID)
            return
        }

        do {
            let state = try await self.fetchState(
                preferenceCenterID: preferenceCenterID
            )
            self.phase = .loaded(state)
        } catch {
            self.phase = .error(error)
        }
    }

    @MainActor
    private func fetchState(preferenceCenterID: String) async throws
        -> PreferenceCenterState
    {
        AirshipLogger.info("Fetching config: \(preferenceCenterID)")

        guard Airship.isFlying else {
            throw AirshipErrors.error("TakeOff not called")
        }

        let config = try await Airship.preferenceCenter.config(
            preferenceCenterID: preferenceCenterID
        )

        var channelSubscriptions: [String] = []
        var contactSubscriptions: [String: Set<ChannelScope>] = [:]

        if config.containsChannelSubscriptions() {
            channelSubscriptions = try await Airship.channel
                .fetchSubscriptionLists()
        }

        if config.containsContactSubscriptions() {
            contactSubscriptions = try await Airship.contact
                .fetchSubscriptionLists()
                .mapValues { Set($0) }
        }
        
        var channelUpdates: AsyncStream<ContactChannelsResult>? = nil

        if config.containsContactManagement() {
            channelUpdates = Airship.contact.contactChannelUpdates
        }

        return PreferenceCenterState(
            config: config,
            contactSubscriptions: contactSubscriptions,
            channelSubscriptions: Set(channelSubscriptions),
            channelUpdates: channelUpdates
        )
    }
}
