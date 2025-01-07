/* Copyright Airship and Contributors */

import Foundation
import Combine

/// NOTE: For internal use only. :nodoc:
public protocol AirshipMeteredUsageProtocol: Sendable {
    func addEvent(_ event: AirshipMeteredUsageEvent) async throws
}

/// NOTE: For internal use only. :nodoc:
public final class AirshipMeteredUsage: AirshipMeteredUsageProtocol {

    private static let workID: String = "MeteredUsage.upload"
    private static let configKey: String = "MeteredUsage.config"
    private static let rateLimitID: String = "MeteredUsage.rateLimit"
    private static let defaultRateLimit: TimeInterval = 30.0
    private static let defaultInitialDelay: TimeInterval = 15.0

    private let config: RuntimeConfig

    private let dataStore: PreferenceDataStore
    private let channel: any AirshipChannelProtocol
    private let contact: any InternalAirshipContactProtocol
    private let client: any MeteredUsageAPIClientProtocol
    private let workManager: any AirshipWorkManagerProtocol
    private let store: MeteredUsageStore
    private let privacyManager: AirshipPrivacyManager

    @MainActor
    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: any AirshipChannelProtocol,
        contact: any InternalAirshipContactProtocol,
        privacyManager: AirshipPrivacyManager
    ) {
        self.init(
            config: config,
            dataStore: dataStore,
            channel: channel,
            contact: contact,
            privacyManager: privacyManager,
            client: MeteredUsageAPIClient(config: config),
            store: MeteredUsageStore(appKey: config.appCredentials.appKey)
        )
    }

    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: any AirshipChannelProtocol,
        contact: any InternalAirshipContactProtocol,
        privacyManager: AirshipPrivacyManager,
        client: any MeteredUsageAPIClientProtocol,
        store: MeteredUsageStore,
        workManager: any AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {
        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.contact = contact
        self.privacyManager = privacyManager
        self.client = client
        self.store = store
        self.workManager = workManager
        
        self.workManager.registerWorker(
            AirshipMeteredUsage.workID
        ) { [weak self] _ in
            guard let self else {
                return .success
            }
            return try await self.performWork()
        }

        self.workManager.autoDispatchWorkRequestOnBackground(
            AirshipWorkRequest(
                workID: AirshipMeteredUsage.workID,
                requiresNetwork: true,
                conflictPolicy: .replace
            )
        )

        self.config.addRemoteConfigListener { [weak self] old, new in
            self?.updateConfig(
                old: old?.meteredUsageConfig,
                new: new.meteredUsageConfig
            )
        }
    }

    @MainActor
    private func updateConfig(old: RemoteConfig.MeteredUsageConfig?, new: RemoteConfig.MeteredUsageConfig?) {
        self.workManager.setRateLimit(
            AirshipMeteredUsage.rateLimitID,
            rate: 1,
            timeInterval: new?.interval ?? AirshipMeteredUsage.defaultRateLimit
        )

        if old?.isEnabled != true && new?.isEnabled == true {
            self.scheduleWork(
                initialDelay: new?.intialDelay ?? AirshipMeteredUsage.defaultInitialDelay
            )
        }
    }

    private func performWork() async throws -> AirshipWorkResult {
        guard self.isEnabled else { return .success }
        
        var events = try await self.store.getEvents()
        guard events.count != 0 else { return .success }

        var channelID: String? = nil
        if (privacyManager.isEnabled(.analytics)) {
            channelID = self.channel.identifier
        } else {
            events = events.map( { $0.withDisabledAnalytics() })
        }

        let result = try await self.client.uploadEvents(
            events,
            channelID: channelID
        )

        guard result.isSuccess else {
            return .failure
        }

        try await self.store.deleteEvents(events)
        return .success
    }

    public func addEvent(_ event: AirshipMeteredUsageEvent) async throws {
        guard self.isEnabled else { return }

        var eventToStore = event
        if (privacyManager.isEnabled(.analytics)) {
            if eventToStore.contactID == nil {
                eventToStore.contactID = await contact.contactID
            }
        } else {
            eventToStore = event.withDisabledAnalytics()
        }
        try await self.store.saveEvent(eventToStore)
        scheduleWork()
    }

    func scheduleWork(initialDelay: TimeInterval = 0.0) {
        guard self.isEnabled else { return }

        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: AirshipMeteredUsage.workID,
                initialDelay: initialDelay,
                requiresNetwork: true,
                conflictPolicy: .keepIfNotStarted
            )
        )
    }
    
    private var isEnabled: Bool {
        return self.config.remoteConfig.meteredUsageConfig?.isEnabled ?? false
    }
}
