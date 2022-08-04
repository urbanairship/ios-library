/* Copyright Airship and Contributors */

import Foundation

/// Delegate protocol for the event manager.
/// For internal use only. :nodoc:
@objc(UAEventManagerDelegate)
public protocol EventManagerDelegate: NSObjectProtocol {
    /// Get the current analytics headers.
    @objc
    func analyticsHeaders(completionHandler: @escaping ([String : String]) -> Void)
}

/// Event manager handles storing and uploading events to Airship.
/// For internal use only. :nodoc:
@objc(UAEventManager)
public class EventManager: NSObject, EventManagerProtocol {

    private static let foregroundTaskBatchDelay: TimeInterval = 1
    private static let backgroundTaskBatchDelay: TimeInterval = 5
    private static let uploadScheduleDelay: TimeInterval = 15
    private static let backgroundLowPriorityEventUploadInterval: TimeInterval = 900
    private static let uploadTask = "UAEventManager.upload"
    private static let fetchEventLimit = 500

    // Max database size
    private static let maxTotalDBSizeBytes = UInt(5) * 1024 * 1024 // local max of 5MB
    private static let minTotalDBSizeBytes = UInt(10) * 1024 // local min of 10KB
    // Total size in bytes that a given event post is allowed to send.
    private static let maxBatchSizeBytes = UInt(500) * 1024 // local max of 500KB
    private static let minBatchSizeBytes = UInt(10) * 1024 // local min of 10KB
    // The actual amount of time in seconds that elapse between event-server posts
    private static let minBatchIntervalSeconds = TimeInterval(60) // local min of 60s
    private static let maxBatchIntervalSeconds = TimeInterval(7 * 24 * 3600) // local max of 7 days
    // Data store keys
    private static let maxTotalDBSizeUserDefaultsKey = "X-UA-Max-Total"
    private static let maxBatchSizeUserDefaultsKey = "X-UA-Max-Batch"
    private static let maxWaitUserDefaultsKey = "X-UA-Max-Wait"
    private static let minBatchIntervalUserDefaultsKey = "X-UA-Min-Batch-Interval"

    private var config: RuntimeConfig
    private var dataStore: PreferenceDataStore
    private var channel: ChannelProtocol
    private var eventStore: EventStoreProtocol
    private var client: EventAPIClientProtocol
    private var notificationCenter: NotificationCenter
    private var appStateTracker: AppStateTracker
    private var taskManager: TaskManagerProtocol
    private var delayProvider: (TimeInterval) -> DelayProtocol

    private let lock = Lock()
    private var nextUploadDate: Date?

    private var maxTotalDBSize: UInt  {
        get {
            var value = UInt(self.dataStore.integer(forKey: EventManager.maxTotalDBSizeUserDefaultsKey))
            value = value == 0 ?  EventManager.maxTotalDBSizeBytes : value
            return self.clamp(value, min:EventManager.minTotalDBSizeBytes, max:EventManager.maxTotalDBSizeBytes)
        }

        set {
            self.dataStore.setInteger(Int(newValue), forKey: EventManager.maxTotalDBSizeUserDefaultsKey)
        }
    }

    private var maxBatchSize: UInt {
        get {
            var value = UInt(self.dataStore.integer(forKey: EventManager.maxBatchSizeUserDefaultsKey))
            value = value == 0 ? EventManager.maxBatchSizeBytes : value
            return self.clamp(value, min: EventManager.minBatchSizeBytes, max: EventManager.maxBatchSizeBytes)
        }

        set {
            self.dataStore.setInteger(Int(newValue), forKey: EventManager.maxBatchSizeUserDefaultsKey)
        }
    }

    private var minBatchInterval: TimeInterval {
        get {
            let value = Double(self.dataStore.integer(forKey: EventManager.minBatchIntervalUserDefaultsKey))
            return self.clamp(value, min: EventManager.minBatchIntervalSeconds, max: EventManager.maxBatchIntervalSeconds)
        }

        set {
            self.dataStore.setInteger(Int(newValue), forKey: EventManager.minBatchIntervalUserDefaultsKey)
        }
    }

    private var lastSendTime: Date {
        get {
            return self.dataStore.object(forKey: "X-UA-Last-Send-Time") as? Date ?? Date.distantPast
        }

        set {
            self.dataStore.setObject(newValue, forKey: "X-UA-Last-Send-Time")
        }
    }

    /// Flag indicating whether event manager uploads are enabled. Defaults to disabled. :nodoc:

    @objc
    public var uploadsEnabled = false

    /// Event manager delegate. :nodoc:
    @objc
    public weak var delegate: EventManagerDelegate?

    /// Default factory method. :nodoc:
    ///
    /// - Parameters:
    ///   - config: The airship config.
    ///   - dataStore: The preference data store.
    ///   - channel: The channel instance.
    ///   
    /// - Returns: UAEventManager instance.
    @objc
    public convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: ChannelProtocol) {
        let eventStore = EventStore(config: config)
        let client = EventAPIClient(config: config)
        let delayProvider =  { (delay: TimeInterval) in
            return Delay(delay)
        }

        self.init(config: config, dataStore: dataStore, channel: channel, eventStore: eventStore,
                  client: client, notificationCenter: NotificationCenter.default, appStateTracker: AppStateTracker.shared,
                  taskManager: TaskManager.shared, delayProvider: delayProvider)


    }

    /// Factory method used for testing. :nodoc:
    ///
    /// - Parameters:
    ///   - config: The airship config.
    ///   - dataStore: The preference data store.
    ///   - channel: The channel instance.
    ///   - eventStore: The event data store.
    ///   - client: The event api client.
    ///   - notificationCenter: The notification center.
    ///   - appStateTracker: The app state tracker.
    ///   - taskManager: The task manager.
    ///   - delayProvider: A delay provider block.
    ///
    /// - Returns: UAEventManager instance.
    @objc
    public init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: ChannelProtocol,
        eventStore: EventStoreProtocol,
        client: EventAPIClientProtocol,
        notificationCenter: NotificationCenter,
        appStateTracker: AppStateTracker,
        taskManager: TaskManagerProtocol,
        delayProvider: @escaping (TimeInterval) -> DelayProtocol) {

        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.eventStore = eventStore
        self.client = client
        self.notificationCenter = notificationCenter
        self.appStateTracker = appStateTracker
        self.taskManager = taskManager
        self.delayProvider = delayProvider

        super.init()

        self.notificationCenter.addObserver(self, selector: #selector(scheduleUpload as () -> Void), name: Channel.channelCreatedEvent, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(applicationDidEnterBackground), name: AppStateTracker.didEnterBackgroundNotification, object: nil)

            self.taskManager.register(taskID: EventManager.uploadTask, dispatcher: UADispatcher.serial(.utility)) { [weak self] task in
            self?.uploadEventsTask(task)
        }
    }

    /// Adds an analytic event to be batched and uploaded to Airship. :nodoc:
    ///
    /// - Parameters:
    ///   - event: The analytic event.
    ///   - eventID: The event ID.
    ///   - eventDate: The event date.
    ///   - sessionID: The analytics session ID.
    @objc
    public func add(_ event: Event, eventID: String, eventDate: Date, sessionID: String) {
        self.eventStore.save(event, eventID: eventID, eventDate: eventDate, sessionID: sessionID)
        self.scheduleUpload(priority:event.priority)
    }

    /// Deletes all events and cancels any uploads in progress. :nodoc:
    @objc
    public func deleteAllEvents() {
        self.eventStore.deleteAllEvents()
    }

    /// Schedules an analytic upload. :nodoc:
    @objc
    public func scheduleUpload() {
        self.scheduleUpload(priority: .normal)
    }

    @objc
    private func applicationDidEnterBackground() {
        self.scheduleUpload(delay: 0)
    }

    private func scheduleUpload(priority: EventPriority) {
        switch (priority) {
        case .high:
            self.scheduleUpload(delay: 0)
        case .normal:
            if self.appStateTracker.state == .background {
                self.scheduleUpload(delay: 0)
            } else {
                self.scheduleUpload(delay: self.calculateNextUploadDelay())
            }
        case .low:
            if self.appStateTracker.state == .background {
                let timeSinceLastSend = Date().timeIntervalSince(self.lastSendTime)
                if timeSinceLastSend < EventManager.backgroundLowPriorityEventUploadInterval {
                    AirshipLogger.trace("Skipping low priority background event send.")
                }
            }
            self.scheduleUpload(delay: self.calculateNextUploadDelay())
        default:
            break
        }
    }

    private func scheduleUpload(delay: TimeInterval) {
        guard self.uploadsEnabled else {
            return
        }

        self.lock.sync {
            let uploadDate = Date(timeIntervalSinceNow: delay)
            if delay > 0 && self.nextUploadDate != nil && self.nextUploadDate?.compare(uploadDate) == .orderedAscending {
                AirshipLogger.trace("Upload already scheduled for an earlier time.")
                return
            }

            self.nextUploadDate = uploadDate

            AirshipLogger.trace("Scheduling upload in \(delay) seconds.")

            self.taskManager.enqueueRequest(taskID: EventManager.uploadTask, options: TaskRequestOptions.defaultOptions, initialDelay: delay)
        }
    }

    private func uploadEventsTask(_ task: AirshipTask) {
        guard self.uploadsEnabled else {
            self.lock.sync {
                self.nextUploadDate = nil;
            }

            task.taskCompleted()
            return
        }

        var batchDelay = EventManager.foregroundTaskBatchDelay

        UADispatcher.main.doSync {
            if self.appStateTracker.state == .background {
                batchDelay = EventManager.backgroundTaskBatchDelay
            }
        }

        self.delayProvider(batchDelay).start()

        self.lock.sync {
            self.nextUploadDate = nil
        }

        guard self.channel.identifier != nil else {
            AirshipLogger.trace("No Channel ID. Skipping analytic upload.")
            task.taskCompleted()
            return
        }

        // Clean up store
        self.eventStore.trimEvents(toStoreSize: self.maxTotalDBSize)

        let events = self.prepareEvents()
        guard events.count > 0 else {
            AirshipLogger.trace("Analytic upload finished, no events to upload.")
            task.taskCompleted()
            return
        }

        let headers = self.prepareHeaders()

        let request = self.client.uploadEvents(events, headers: headers) { [weak self] response, error in
            guard let self = self else {
                return
            }

            self.lastSendTime = Date()

            if let error = error {
                AirshipLogger.trace("Analytics upload request failed: \(error)")
                task.taskFailed()
            } else {
                let response = response!
                if response.isSuccess {
                    AirshipLogger.trace("Analytic upload success")
                    self.eventStore.deleteEvents(withIDs: events.map({ event in
                        return event["event_id"] as? String ?? ""
                    }))

                    self.updateAnalyticsParameters(response: response)
                    task.taskCompleted()

                    UADispatcher.main.dispatchAsync {
                        self.scheduleUpload()
                    }
                } else {
                    AirshipLogger.trace("Analytics upload request failed with status: \(response.status)")
                    task.taskFailed()
                }
            }
        }

        task.expirationHandler = {
            request.dispose()
        }
    }

    private func updateAnalyticsParameters(response: EventAPIResponse) {
        if let maxTotalDBSizeNumber = response.maxTotalDBSize {
            self.maxTotalDBSize = maxTotalDBSizeNumber.uintValue * 1024
        }

        if let maxBatchSizeNumber = response.maxBatchSize {
            self.maxBatchSize = maxBatchSizeNumber.uintValue * 1024 // value expressed in kB
        }

        if let minBatchIntervalNumber = response.minBatchInterval {
            self.minBatchInterval = minBatchIntervalNumber.doubleValue
        }
    }


    private func calculateNextUploadDelay() -> TimeInterval {
        var delay: TimeInterval = 0;
        let timeSincelastSend = Date().timeIntervalSince(self.lastSendTime)

        if timeSincelastSend < self.minBatchInterval {
            delay = self.minBatchInterval - timeSincelastSend
        }

        return max(delay, EventManager.uploadScheduleDelay)
    }

    private func prepareHeaders() -> [String: String] {
        guard let delegate = delegate else {
            return [:]
        }

        let semaphore = Semaphore()
        var headers: [String: String]!
        delegate.analyticsHeaders { result in
            headers = result
            semaphore.signal()
        }
        semaphore.wait()
        return headers
    }

    private func prepareEvents() -> [[String : AnyHashable]] {
        var preparedEvents: [[String: AnyHashable]] = []
        let semaphore = Semaphore()

        let maxBatchSize = self.maxBatchSize

        self.eventStore.fetchEvents(withLimit: EventManager.fetchEventLimit) { result in
            if result.count > 0 {
                var batchSize = 0
                for eventData in result {
                    if let bytes = eventData.bytes, let data = eventData.data {
                        if batchSize + bytes.intValue > maxBatchSize {
                            break
                        }

                        batchSize += bytes.intValue

                        var eventBody: [String: AnyHashable] = [:]
                        eventBody["event_id"] =  eventData.identifier
                        eventBody["time"] = eventData.time
                        eventBody["type"] = eventData.type

                        do {
                            if var jsonData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyHashable] {
                                jsonData["session_id"] = eventData.sessionID
                                eventBody["data"] = jsonData

                                preparedEvents.append(eventBody)
                            } else {
                                AirshipLogger.error("Failed to deserialize event.")
                                eventData.managedObjectContext?.delete(eventData)
                            }
                        } catch {
                            AirshipLogger.error("Failed to deserialize event \(eventData): \(error)")
                            eventData.managedObjectContext?.delete(eventData)
                        }
                    }
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
        return preparedEvents
    }

    private func clamp<T>(_ value: T, min: T, max: T) -> T where T : Comparable {
        if value < min {
            return min;
        }

        if value > max {
            return max;
        }

        return value;
    }
}
