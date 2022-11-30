/* Copyright Airship and Contributors */

import Combine

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataManager)
public class RemoteDataManager: NSObject, Component, RemoteDataProvider {

    static let refreshTaskID = "RemoteDataManager.refresh"
    static let defaultRefreshInterval: TimeInterval = 10
    static let refreshRemoteDataPushPayloadKey =
        "com.urbanairship.remote-data.update"

    // Datastore keys
    private static let refreshIntervalKey = "remotedata.REFRESH_INTERVAL"
    private static let lastRefreshMetadataKey =
        "remotedata.LAST_REFRESH_METADATA"
    private static let lastRefreshTimeKey = "remotedata.LAST_REFRESH_TIME"
    private static let lastRefreshAppVersionKey =
        "remotedata.LAST_REFRESH_APP_VERSION"
    private static let lastRemoteDataModifiedTime =
        "UALastRemoteDataModifiedTime"
    private static let deviceRandomValueKey = "remotedata.randomValue"

    private let dataStore: PreferenceDataStore
    private let apiClient: RemoteDataAPIClientProtocol
    private let remoteDataStore: RemoteDataStore
    private let date: AirshipDate
    private let notificationCenter: NotificationCenter
    private let appStateTracker: AppStateTracker
    private let localeManager: LocaleManagerProtocol
    private let taskManager: TaskManagerProtocol
    private let privacyManager: PrivacyManager
    private let networkMonitor: NetworkMonitor

    private var updatedSinceLastForeground = false

    private var refreshCompletionHandlers: [((Bool) -> Void)?] = []
    private let refreshLock = Lock()
    private var isRefreshing = false

    private let updateSubject = PassthroughSubject<[RemoteDataPayload], Never>()

    public var remoteDataRefreshInterval: TimeInterval {
        get {
            let fromStore =
                self.dataStore.object(
                    forKey: RemoteDataManager.refreshIntervalKey
                )
                as? TimeInterval
            return fromStore ?? RemoteDataManager.defaultRefreshInterval
        }
        set {
            self.dataStore.setDouble(
                newValue,
                forKey: RemoteDataManager.refreshIntervalKey
            )
        }
    }

    @objc
    public var lastModified: String? {
        get {
            return self.dataStore.string(
                forKey: RemoteDataManager.lastRemoteDataModifiedTime
            )
        }
        set {
            self.dataStore.setObject(
                newValue,
                forKey: RemoteDataManager.lastRemoteDataModifiedTime
            )
        }
    }

    private var lastMetadata: [AnyHashable: Any]? {
        get {
            return self.dataStore.object(
                forKey: RemoteDataManager.lastRefreshMetadataKey
            ) as? [AnyHashable: Any]
        }
        set {
            self.dataStore.setObject(
                newValue,
                forKey: RemoteDataManager.lastRefreshMetadataKey
            )
        }
    }

    private var lastRefreshTime: Date {
        get {
            return self.dataStore.object(
                forKey: RemoteDataManager.lastRefreshTimeKey
            )
                as? Date ?? Date.distantPast
        }
        set {
            self.dataStore.setValue(
                newValue,
                forKey: RemoteDataManager.lastRefreshTimeKey
            )
        }
    }

    private var lastAppVersion: String? {
        get {
            return self.dataStore.string(
                forKey: RemoteDataManager.lastRefreshAppVersionKey
            )
        }
        set {
            self.dataStore.setValue(
                newValue,
                forKey: RemoteDataManager.lastRefreshAppVersionKey
            )
        }
    }

    private let disableHelper: ComponentDisableHelper

    @objc
    private lazy var randomValue: Int = {
        guard
            let storedRandomValue = self.dataStore.object(
                forKey: RemoteDataManager.deviceRandomValueKey
            ) as? Int
        else {
            let randomValue = Int.random(in: 0...9999)
            self.dataStore.setObject(
                randomValue,
                forKey: RemoteDataManager.deviceRandomValueKey
            )
            return randomValue
        }
        return storedRandomValue
    }()

    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }

    @objc
    public convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        localeManager: LocaleManagerProtocol,
        privacyManager: PrivacyManager
    ) {

        self.init(
            dataStore: dataStore,
            localeManager: localeManager,
            privacyManager: privacyManager,
            apiClient: RemoteDataAPIClient(config: config),
            remoteDataStore: RemoteDataStore(
                storeName: "RemoteData-\(config.appKey).sqlite"
            ),
            taskManager: TaskManager.shared,
            date: AirshipDate(),
            notificationCenter: NotificationCenter.default,
            appStateTracker: AppStateTracker.shared,
            networkMonitor: NetworkMonitor()
        )

    }

    @objc
    public init(
        dataStore: PreferenceDataStore,
        localeManager: LocaleManagerProtocol,
        privacyManager: PrivacyManager,
        apiClient: RemoteDataAPIClientProtocol,
        remoteDataStore: RemoteDataStore,
        taskManager: TaskManagerProtocol,
        date: AirshipDate,
        notificationCenter: NotificationCenter,
        appStateTracker: AppStateTracker,
        networkMonitor: NetworkMonitor
    ) {

        self.dataStore = dataStore
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.apiClient = apiClient
        self.remoteDataStore = remoteDataStore
        self.taskManager = taskManager
        self.date = date
        self.notificationCenter = notificationCenter
        self.appStateTracker = appStateTracker
        self.networkMonitor = networkMonitor

        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "UARemoteDataManager"
        )

        super.init()

        self.notificationCenter.addObserver(
            self,
            selector: #selector(checkRefresh),
            name: LocaleManager.localeUpdatedEvent,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(enqueueRefreshTask),
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(checkRefresh),
            name: PrivacyManager.changeEvent,
            object: nil
        )

        self.taskManager.register(
            taskID: RemoteDataManager.refreshTaskID,
            type: .serial
        ) { [weak self] task in

            guard let self = self,
                self.privacyManager.isAnyFeatureEnabled()
            else {
                task.taskCompleted()
                return
            }

            self.handleRefreshTask(task)
        }

        self.checkRefresh()
    }

    @objc
    private func checkRefresh() {
        if self.shouldRefresh() {
            self.enqueueRefreshTask()
        }
    }

    @objc
    private func applicationDidForeground() {
        self.updatedSinceLastForeground = false
        self.checkRefresh()
    }

    @objc
    private func enqueueRefreshTask() {
        if self.privacyManager.isAnyFeatureEnabled() {
            isRefreshing = true
            self.taskManager.enqueueRequest(
                taskID: RemoteDataManager.refreshTaskID,
                options: TaskRequestOptions.defaultOptions
            )
        }
    }

    private func handleRefreshTask(_ task: AirshipTask) {
        let lastModified =
            self.isLastMetadataCurrent() ? self.lastModified : nil
        let locale = self.localeManager.currentLocale

        var success = false

        let request = self.apiClient.fetchRemoteData(
            locale: locale,
            randomValue: self.randomValue,
            lastModified: lastModified
        ) { response, error in
            guard let response = response else {
                if let error = error {
                    AirshipLogger.error(
                        "Failed to refresh remote-data with error \(error)"
                    )
                } else {
                    AirshipLogger.error("Failed to refresh remote-data")
                }

                task.taskFailed()
                return
            }

            AirshipLogger.debug(
                "Remote data refresh finished with response: \(response)"
            )
            AirshipLogger.trace(
                "Remote data refresh finished with payloads: \(response.payloads ?? [])"
            )

            if response.status == 304 {
                self.updatedSinceLastForeground = true
                self.lastRefreshTime = self.date.now
                self.lastAppVersion = Utils.bundleShortVersionString()
                success = true
                task.taskCompleted()
            } else if response.isSuccess {
                success = true
                let payloads = response.payloads ?? []

                self.remoteDataStore.overwriteCachedRemoteData(payloads) {
                    success in
                    if success {
                        self.lastMetadata = response.metadata
                        self.lastModified = response.lastModified
                        self.lastRefreshTime = self.date.now
                        self.lastAppVersion = Utils.bundleShortVersionString()
                        self.updateSubject.send(payloads)
                        self.updatedSinceLastForeground = true
                        task.taskCompleted()
                    } else {
                        AirshipLogger.error("Failed to save remote-data.")
                        task.taskFailed()
                    }
                }
            } else {
                AirshipLogger.debug("Failed to refresh remote-data")
                if response.isServerError {
                    task.taskFailed()
                } else {
                    task.taskCompleted()
                }
            }
        }

        task.expirationHandler = {
            request.dispose()
        }

        task.completionHandler = {
            self.refreshLock.sync {
                for completionHandler in self.refreshCompletionHandlers {
                    if let handler = completionHandler {
                        handler(success)
                    }
                }
                self.refreshCompletionHandlers.removeAll()
                self.isRefreshing = false
            }
        }
    }

    private func createMetadata(locale: Locale, lastModified: String?)
        -> [AnyHashable: Any]
    {
        return self.apiClient.metadata(
            locale: locale,
            randomValue: self.randomValue,
            lastModified: lastModified
        )
    }

    public func isMetadataCurrent(_ metadata: [AnyHashable: Any]) -> Bool {
        let last = (self.lastMetadata ?? [:]) as NSDictionary
        let metadata = metadata as NSDictionary

        return metadata.isEqual(last)
    }

    public func refresh(
        force: Bool,
        completionHandler: @escaping (Bool) -> Void
    ) {
        refreshLock.sync {
            if (!(force || shouldRefresh())) {
                // Already up to date
                completionHandler(true)
            } else if self.networkMonitor.isConnected {
                self.refreshCompletionHandlers.append(completionHandler)
                if !isRefreshing {
                    enqueueRefreshTask()
                }
            } else {
                completionHandler(false)
            }
        }
    }

    private func isLastAppVersionCurrent() -> Bool {
        let lastAppRefreshVersion = self.dataStore.string(
            forKey: RemoteDataManager.lastRefreshAppVersionKey
        )
        let currentAppVersion = Utils.bundleShortVersionString()
        return lastAppRefreshVersion == currentAppVersion
    }

    private func isLastMetadataCurrent() -> Bool {
        let current = self.createMetadata(
            locale: self.localeManager.currentLocale,
            lastModified: self.lastModified
        )
        return isMetadataCurrent(current)
    }

    private func shouldRefresh() -> Bool {
        guard self.privacyManager.isAnyFeatureEnabled(),
            self.appStateTracker.state == .active
        else {
            return false
        }

        guard self.isLastAppVersionCurrent(),
            self.isLastMetadataCurrent()
        else {
            return true
        }

        if !self.updatedSinceLastForeground {
            let timeSinceLastRefresh = self.date.now.timeIntervalSince(
                self.lastRefreshTime
            )
            if timeSinceLastRefresh >= self.remoteDataRefreshInterval {
                return true
            }
        }

        return false
    }

    public func current(types: [String]) -> Future<[RemoteDataPayload], Never> {
        return Future { promise in
            let predicate = NSPredicate(format: "(type IN %@)", types)
            self.remoteDataStore.fetchRemoteDataFromCache(predicate: predicate)
            {
                payloads in
                promise(.success(payloads))
            }
        }
    }

    public func publisher(types: [String]) -> AnyPublisher<
        [RemoteDataPayload], Never
    > {
        return self.updateSubject
            .prepend(current(types: types))
            .map { payloads -> [RemoteDataPayload] in
                var filtered = payloads.filter { types.contains($0.type) }
                filtered.sort { first, second in
                    let firstIndex = types.firstIndex(of: first.type) ?? 0
                    let secondIndex = types.firstIndex(of: second.type) ?? 0
                    return firstIndex < secondIndex
                }
                return filtered
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func subscribe(
        types: [String],
        block: @escaping ([RemoteDataPayload]) -> Void
    ) -> Disposable {

        let cancellable = publisher(types: types)
            .receive(on: RunLoop.main)
            .sink { payloads in
                block(payloads)
            }

        return Disposable {
            cancellable.cancel()
        }
    }
}

#if !os(watchOS)
extension RemoteDataManager: PushableComponent {
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if notification[RemoteDataManager.refreshRemoteDataPushPayloadKey]
            == nil
        {
            completionHandler(.noData)
        } else {
            self.enqueueRefreshTask()
            completionHandler(.newData)
        }
    }
}
#endif
