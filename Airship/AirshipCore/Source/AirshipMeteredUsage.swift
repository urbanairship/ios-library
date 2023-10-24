/* Copyright Airship and Contributors */

import Foundation

public final class AirshipMeteredUsage: Sendable {

    private static let workID: String = "MeteredUsage.upload"
    private static let configKey: String = "MeteredUsage.config"
    private static let rateLimitID: String = "MeteredUsage.rateLimit"
    private static let defaultRateLimit: TimeInterval = 30.0
    private static let defaultInitialDelay: TimeInterval = 15.0

    private let dataStore: PreferenceDataStore
    private let channel: AirshipChannelProtocol
    private let client: MeteredUsageAPIClientProtocol
    private let workManager: AirshipWorkManagerProtocol
    private let store: MeteredUsageStore
    private let privacyManager: AirshipPrivacyManager
    private let meteredUsageConfig: Atomic<MeteredUsageConfig?> = Atomic(nil)

    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: AirshipChannelProtocol,
        privacyManager: AirshipPrivacyManager
    ) {
        self.init(
            dataStore: dataStore,
            channel: channel,
            privacyManager: privacyManager,
            client: MeteredUsageAPIClient(config: config),
            store: MeteredUsageStore(appKey: config.appKey)
        )
    }

    init(
        dataStore: PreferenceDataStore,
        channel: AirshipChannelProtocol,
        privacyManager: AirshipPrivacyManager,
        client: MeteredUsageAPIClientProtocol,
        store: MeteredUsageStore,
        workManager: AirshipWorkManagerProtocol = AirshipWorkManager.shared
    ) {
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        self.client = client
        self.store = store
        self.workManager = workManager
        
        self.workManager.registerWorker(
            AirshipMeteredUsage.workID,
            type: .serial
        ) { [weak self] _ in
            guard let self = self else {
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
    }

    func updateConfig(_ newConfig: MeteredUsageConfig?) {
        let oldConfig = self.meteredUsageConfig.value
        guard oldConfig != newConfig else {
            return
        }

        self.meteredUsageConfig.value = newConfig

        self.workManager.setRateLimit(
            AirshipMeteredUsage.rateLimitID,
            rate: 1,
            timeInterval: newConfig?.interval ?? AirshipMeteredUsage.defaultRateLimit
        )

        if oldConfig?.isEnabled != true && newConfig?.isEnabled == true {
            self.scheduleWork(
                initialDelay: newConfig?.initialDelay ?? AirshipMeteredUsage.defaultInitialDelay
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

    func addEvent(_ event: AirshipMeteredUsageEvent) async throws {
        let eventToStore = privacyManager.isEnabled(.analytics) ? event : event.withDisabledAnalytics()
        try await self.store.saveEvent(eventToStore)
        scheduleWork()
    }

    func scheduleWork(
        initialDelay: TimeInterval = 0.0
    ) {
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
        return self.meteredUsageConfig.value?.isEnabled ?? false
    }
}

@objc
public final class InAppMeteredUsage: NSObject {
    private let meteredUsage: AirshipMeteredUsage
    private let contact: InternalAirshipContactProtocol

    init(meteredUsage: AirshipMeteredUsage, contact: InternalAirshipContactProtocol) {
        self.meteredUsage = meteredUsage
        self.contact = contact
    }

    @objc
    public func addImpression(
        entityID: String,
        product: String,
        contactID: String?,
        reportingContext: Any?
    ) {
        let date = Date()
        let reportingContextJSON = try? AirshipJSON.wrap(reportingContext)


        Task {
            let lastContactID = await contact.contactID

            let event = AirshipMeteredUsageEvent(
                eventID: UUID().uuidString,
                entityID: entityID,
                type: .inAppExperienceImpression,
                product: product,
                reportingContext: reportingContextJSON,
                timestamp: date,
                contactId: contactID ?? lastContactID
            )

            do {
                try await self.meteredUsage.addEvent(event)
            } catch {
                AirshipLogger.error("Failed to save metered usage event: \(event)")
            }
        }

    }
}
