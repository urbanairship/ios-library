import Foundation

protocol EventManagerProtocol: AnyObject, Sendable {
    var uploadsEnabled: Bool { get set }
    func addEvent(_ event: AirshipEventData) async throws
    func deleteEvents() async throws
    func scheduleUpload(eventPriority: EventPriority) async

    func addHeaderProvider(
        _ headerProvider: @Sendable @escaping () async -> [String: String]
    )
}

final class EventManager: EventManagerProtocol {

    private let _uploadsEnabled = Atomic<Bool>(false)
    var uploadsEnabled: Bool  {
        get {
            _uploadsEnabled.value
        }
        set {
            _uploadsEnabled.value = newValue
        }
    }

    private let eventStore: EventStore
    private let eventAPIClient: EventAPIClientProtocol
    private let eventScheduler: EventUploadSchedulerProtocol
    private let state: EventManagerState

    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore
    ) {
        self.init(
            dataStore: dataStore,
            eventStore: EventStore(appKey: config.appKey),
            eventAPIClient: EventAPIClient(config: config)
        )
    }

    init(
        dataStore: PreferenceDataStore,
        eventStore: EventStore,
        eventAPIClient: EventAPIClientProtocol,
        eventScheduler: EventUploadSchedulerProtocol = EventUploadScheduler()
    ) {
        self.eventStore = eventStore
        self.eventAPIClient = eventAPIClient
        self.eventScheduler = eventScheduler
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

    func addHeaderProvider(
        _ headerProvider: @Sendable @escaping () async -> [String : String]
    ) {
        Task {
            await self.state.addHeaderProvider(headerProvider)
        }
    }

    func scheduleUpload(eventPriority: EventPriority) async {
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

        let events = try await self.prepareEvents()
        guard !events.isEmpty else {
            AirshipLogger.trace(
                "Analytic upload finished, no events to upload."
            )
            return .success
        }

        let headers = await self.state.prepareHeaders()
        let response = try await self.eventAPIClient.uploadEvents(
            events,
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
    private var headerBlocks: [(@Sendable () async -> [String: String])] = []

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
        AirshipUtils.clamp(
            self.tuningInfo?.minBatchInterval ?? EventManagerState.minBatchInterval,
            min: EventManagerState.minBatchInterval,
            max: EventManagerState.maxBatchInterval
        )
    }

    var maxTotalStoreSizeKB: UInt {
        AirshipUtils.clamp(
            self.tuningInfo?.maxTotalStoreSizeKB ?? EventManagerState.maxTotalDBSizeKB,
            min: EventManagerState.minTotalDBSizeKB,
            max: EventManagerState.maxTotalDBSizeKB
        )
    }

    var maxBatchSizeKB: UInt {
        AirshipUtils.clamp(
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

    func addHeaderProvider(
        _ headerProvider: @Sendable @escaping () async -> [String: String]
    ) {
        self.headerBlocks.append(headerProvider)
    }

    func prepareHeaders() async -> [String: String] {
        var allHeaders: [String: String] = [:]
        for headerBlock in self.headerBlocks {
            let headers = await headerBlock()
            allHeaders.merge(headers) { (_, new) in
                AirshipLogger.warn("Analytic header merge conflict \(new)")
                return new
            }
        }
        return allHeaders
    }
}
