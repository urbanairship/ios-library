import Foundation

protocol EventManagerProtocol {
    var uploadsEnabled: Bool { get set }
    func addEvent(_ event: AirshipEventData) async throws
    func deleteEvents() async throws
    func scheduleUpload(eventPriority: EventPriority) async

    func addHeaderProvider(
        _ headerProvider: @escaping  () async -> [String: String]
    )
}

class EventManager: EventManagerProtocol {
    private static let tuninigInfoDefaultsKey = "Analytics.tuningInfo"

    // Max database size
    private static let maxTotalDBSizeKB: UInt = 5120
    private static let minTotalDBSizeKB: UInt = 10

    // Total size in bytes that a given event post is allowed to send.
    private static let maxBatchSizeKB: UInt = 500
    private static let minBatchSizeKB: UInt = 10

    // The actual amount of time in seconds that elapse between event-server posts
    private static let minBatchInterval: TimeInterval = 60
    private static let maxBatchInterval: TimeInterval = 604800 // 7 days

    var uploadsEnabled: Bool = false
    private let dataStore: PreferenceDataStore
    private let eventStore: EventStore
    private let eventAPIClient: EventAPIClientProtocol
    private let eventScheduler: EventUploadSchedulerProtocol
    private var headerBlocks: [(() async -> [String: String])] = []

    private var _tuningInfo: EventUploadTuningInfo?
    private var tuningInfo: EventUploadTuningInfo? {
        get {
            if let tuningInfo = self._tuningInfo {
                return tuningInfo
            }

            self._tuningInfo = try? self.dataStore.codable(
                forKey: EventManager.tuninigInfoDefaultsKey
            )

            return self._tuningInfo
        }

        set {
            self._tuningInfo = newValue
            try? self.dataStore.setCodable(
                newValue,
                forKey: EventManager.tuninigInfoDefaultsKey
            )
        }
    }


    private var minBatchInterval: TimeInterval {
        Utils.clamp(
            self.tuningInfo?.minBatchInterval ?? EventManager.minBatchInterval,
            min: EventManager.minBatchInterval,
            max: EventManager.maxBatchInterval
        )
    }

    private var maxTotalStoreSizeKB: UInt {
        Utils.clamp(
            self.tuningInfo?.maxTotalStoreSizeKB ?? EventManager.maxTotalDBSizeKB,
            min: EventManager.minTotalDBSizeKB,
            max: EventManager.maxTotalDBSizeKB
        )
    }

    private var maxBatchSizeKB: UInt {
        Utils.clamp(
            self.tuningInfo?.maxBatchSizeKB ?? EventManager.maxBatchSizeKB,
            min: EventManager.minBatchSizeKB,
            max: EventManager.maxBatchSizeKB
        )
    }


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
        self.dataStore = dataStore
        self.eventStore = eventStore
        self.eventAPIClient = eventAPIClient
        self.eventScheduler = eventScheduler

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
        _ headerProvider: @escaping () async -> [String : String]
    ) {
        self.headerBlocks.append(headerProvider)
    }

    func scheduleUpload(eventPriority: EventPriority) async {
        guard self.uploadsEnabled else { return }

        await self.eventScheduler.scheduleUpload(
            eventPriority: eventPriority,
            minBatchInterval: self.minBatchInterval
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

        let headers = await self.prepareHeaders()
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

        self.tuningInfo = response.result

        await self.scheduleUpload(eventPriority: .normal)

        return .success
    }

    private func prepareEvents() async throws -> [AirshipEventData] {
        do {
            try await self.eventStore.trimEvents(
                maxStoreSizeKB: self.maxTotalStoreSizeKB
            )
        } catch {
            AirshipLogger.warn("Unable to trim database: \(error)")
        }

        return try await self.eventStore.fetchEvents(
            maxBatchSizeKB: self.maxBatchSizeKB
        )
    }

    private func prepareHeaders() async -> [String: String] {
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
