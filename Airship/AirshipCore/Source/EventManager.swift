import Foundation

protocol EventManagerProtocol: AnyObject, Sendable {
    var uploadsEnabled: Bool { get set }
    func addEvent(_ event: AirshipEventData) async throws
    func deleteEvents() async throws
    func scheduleUpload(eventPriority: AirshipEventPriority) async

    @MainActor
    func addHeaderProvider(
        _ headerProvider: @Sendable @escaping () async -> [String: String]
    )
}

final class EventManager: EventManagerProtocol {

    private let headerBlocks: AirshipMainActorValue<[@Sendable () async -> [String: String]]> = AirshipMainActorValue([])

    private let _uploadsEnabled = AirshipAtomicValue<Bool>(false)
    var uploadsEnabled: Bool  {
        get {
            _uploadsEnabled.value
        }
        set {
            _uploadsEnabled.value = newValue
        }
    }

    private let eventStore: EventStore
    private let eventAPIClient: any EventAPIClientProtocol
    private let eventScheduler: any EventUploadSchedulerProtocol
    private let state: EventManagerState
    private let channel: any AirshipChannel

    @MainActor
    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: any AirshipChannel
    ) {
        self.init(
            dataStore: dataStore,
            channel: channel,
            eventStore: EventStore(appKey: config.appCredentials.appKey),
            eventAPIClient: EventAPIClient(config: config)
        )
    }

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        channel: any AirshipChannel,
        eventStore: EventStore,
        eventAPIClient: any EventAPIClientProtocol,
        eventScheduler: (any EventUploadSchedulerProtocol)? = nil
    ) {
        self.channel = channel
        self.eventStore = eventStore
        self.eventAPIClient = eventAPIClient
        self.eventScheduler = eventScheduler ?? EventUploadScheduler()
        self.state = EventManagerState(dataStore: dataStore)

        Task {
            await self.eventScheduler.setWorkBlock { [weak self] in
                try await self?.uploadEvents() ?? .success
            }
        }
    }

    func addEvent(_ event: AirshipEventData) async throws {
        try await self.eventStore.save(event: event)
    }

    func deleteEvents() async throws {
        try await self.eventStore.deleteAllEvents()
    }

    @MainActor
    func addHeaderProvider(
        _ headerProvider: @Sendable @escaping () async -> [String : String]
    ) {
        self.headerBlocks.update { $0.append(headerProvider) }
    }

    func scheduleUpload(eventPriority: AirshipEventPriority) async {
        guard self.uploadsEnabled else { return }

        await self.eventScheduler.scheduleUpload(
            eventPriority: eventPriority,
            minBatchInterval: await self.state.minBatchInterval
        )
    }

    private func uploadEvents() async throws -> AirshipWorkResult {
        guard self.uploadsEnabled else {
            return .success
        }

        guard let channelID = channel.identifier else {
            return .success
        }

        let events = try await self.prepareEvents()
        guard !events.isEmpty else {
            AirshipLogger.trace(
                "Analytic upload finished, no events to upload."
            )
            return .success
        }

        let headers = await self.prepareHeaders()
        let response = try await self.eventAPIClient.uploadEvents(
            events,
            channelID: channelID,
            headers: headers
        )

        guard response.isSuccess else {
            AirshipLogger.trace(
                "Analytics upload request failed with status: \(response.statusCode)"
            )
            return .failure
        }

        AirshipLogger.trace("Analytic upload success")
        try await self.eventStore.deleteEvents(
            eventIDs: events.map { event in
                return event.id
            }
        )

        await self.state.updateTuniningInfo(response.result)

        if (try? await self.eventStore.hasEvents()) == true {
            await self.scheduleUpload(eventPriority: .normal)
        }

        return .success
    }

    private func prepareEvents() async throws -> [AirshipEventData] {
        do {
            try await self.eventStore.trimEvents(
                maxStoreSizeKB: await self.state.maxTotalStoreSizeKB
            )
        } catch {
            AirshipLogger.warn("Unable to trim database: \(error)")
        }

        return try await self.eventStore.fetchEvents(
            maxBatchSizeKB: await self.state.maxBatchSizeKB
        )
    }

    @MainActor
    private func prepareHeaders() async -> [String: String] {
        let providers = self.headerBlocks.value

        var allHeaders: [String: String] = [:]
        for headerBlock in providers {
            let headers = await headerBlock()
            allHeaders.merge(headers) { (_, new) in
                AirshipLogger.warn("Analytic header merge conflict \(new)")
                return new
            }
        }
        return allHeaders
    }
}

fileprivate actor EventManagerState {

    // Max database size
    private static let maxTotalDBSizeKB: UInt = 5120
    private static let minTotalDBSizeKB: UInt = 10
    private static let tuninigInfoDefaultsKey = "Analytics.tuningInfo"

    // Total size in bytes that a given event post is allowed to send.
    private static let maxBatchSizeKB: UInt = 500
    private static let minBatchSizeKB: UInt = 10

    // The actual amount of time in seconds that elapse between event-server posts
    private static let minBatchInterval: TimeInterval = 60
    private static let maxBatchInterval: TimeInterval = 604800 // 7 days

    private var _tuningInfo: EventUploadTuningInfo?
    private var tuningInfo: EventUploadTuningInfo? {
        get {
            if let tuningInfo = self._tuningInfo {
                return tuningInfo
            }

            self._tuningInfo = try? self.dataStore.codable(
                forKey: EventManagerState.tuninigInfoDefaultsKey
            )

            return self._tuningInfo
        }

        set {
            self._tuningInfo = newValue
            try? self.dataStore.setCodable(
                newValue,
                forKey: EventManagerState.tuninigInfoDefaultsKey
            )
        }
    }


    var minBatchInterval: TimeInterval {
        Self.clamp(
            self.tuningInfo?.minBatchInterval ?? EventManagerState.minBatchInterval,
            min: EventManagerState.minBatchInterval,
            max: EventManagerState.maxBatchInterval
        )
    }

    var maxTotalStoreSizeKB: UInt {
        Self.clamp(
            self.tuningInfo?.maxTotalStoreSizeKB ?? EventManagerState.maxTotalDBSizeKB,
            min: EventManagerState.minTotalDBSizeKB,
            max: EventManagerState.maxTotalDBSizeKB
        )
    }

    var maxBatchSizeKB: UInt {
        Self.clamp(
            self.tuningInfo?.maxBatchSizeKB ?? EventManagerState.maxBatchSizeKB,
            min: EventManagerState.minBatchSizeKB,
            max: EventManagerState.maxBatchSizeKB
        )
    }

    let dataStore: PreferenceDataStore

    init(dataStore: PreferenceDataStore) {
        self.dataStore = dataStore
    }

    func updateTuniningInfo(_ tuningInfo: EventUploadTuningInfo?) {
        self.tuningInfo = tuningInfo
    }


    static func clamp<T>(_ value: T, min: T, max: T) -> T where T: Comparable {
        if value < min {
            return min
        }

        if value > max {
            return max
        }

        return value
    }
}
