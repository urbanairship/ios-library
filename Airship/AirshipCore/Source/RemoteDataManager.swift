/* Copyright Airship and Contributors */

import Combine

// NOTE: For internal use only. :nodoc:
public class RemoteDataManager: NSObject, Component, RemoteDataProvider {

    static let refreshTaskID = "RemoteDataManager.refresh"
    static let defaultRefreshInterval: TimeInterval = 10
    static let refreshRemoteDataPushPayloadKey = "com.urbanairship.remote-data.update"

    // Datastore keys
    private static let refreshIntervalKey = "remotedata.REFRESH_INTERVAL"
    private static let lastRefreshMetadataKey = "remotedata.LAST_REFRESH_METADATA"
    private static let lastRefreshTimeKey = "remotedata.LAST_REFRESH_TIME"
    private static let lastRefreshAppVersionKey = "remotedata.LAST_REFRESH_APP_VERSION"
    private static let lastRemoteDataModifiedTime = "UALastRemoteDataModifiedTime"
    private static let deviceRandomValueKey = "remotedata.randomValue"

    private let dataStore: PreferenceDataStore
    private let apiClient: RemoteDataAPIClientProtocol
    private let remoteDataStore: RemoteDataStore
    private let date: AirshipDateProtocol
    private let notificationCenter: NotificationCenter
    private let appStateTracker: AppStateTrackerProtocol
    private let localeManager: AirshipLocaleManagerProtocol
    private let workManager: AirshipWorkManagerProtocol
    private let privacyManager: AirshipPrivacyManager
    private let networkMonitor: NetworkMonitor

    private let updatedSinceLastForeground: Atomic<Bool> = Atomic(false)

    private var refreshCompletionHandlers: [(@Sendable (Bool) -> Void)?] = []
    private let refreshLock = AirshipLock()
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

    var lastModified: String? {
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
            self.dataStore.setObject(
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
            self.dataStore.setObject(
                newValue,
                forKey: RemoteDataManager.lastRefreshAppVersionKey
            )
        }
    }

    private let disableHelper: ComponentDisableHelper

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

    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        localeManager: AirshipLocaleManagerProtocol,
        privacyManager: AirshipPrivacyManager
    ) {
        self.init(
            dataStore: dataStore,
            localeManager: localeManager,
            privacyManager: privacyManager,
            apiClient: RemoteDataAPIClient(config: config),
            remoteDataStore: RemoteDataStore(
                storeName: "RemoteData-\(config.appKey).sqlite"
            )
        )
    }

    init(
        dataStore: PreferenceDataStore,
        localeManager: AirshipLocaleManagerProtocol,
        privacyManager: AirshipPrivacyManager,
        apiClient: RemoteDataAPIClientProtocol,
        remoteDataStore: RemoteDataStore,
        workManager: AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        date: AirshipDateProtocol = AirshipDate.shared,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        appStateTracker: AppStateTrackerProtocol = AppStateTracker.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.dataStore = dataStore
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.apiClient = apiClient
        self.remoteDataStore = remoteDataStore
        self.workManager = workManager
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
            name: AirshipLocaleManager.localeUpdatedEvent,
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
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )
        
        self.workManager.registerWorker(
            RemoteDataManager.refreshTaskID,
            type: .serial
        ) { [weak self] _ in
            return try await self?.handleRefreshTask() ?? .success
        }
    }
    
    @MainActor
    public func airshipReady() {
        self.checkRefresh()
    }

    @objc
    @MainActor
    private func checkRefresh() {
        if self.shouldRefresh(state: self.appStateTracker.state) {
            self.enqueueRefreshTask()
        }
    }

    @objc
    @MainActor
    private func applicationDidForeground() {
        self.updatedSinceLastForeground.value = false
        self.checkRefresh()
    }

    @objc
    private func enqueueRefreshTask() {
        if self.privacyManager.isAnyFeatureEnabled() {
            isRefreshing = true
            self.workManager.dispatchWorkRequest(
                AirshipWorkRequest(
                    workID: RemoteDataManager.refreshTaskID,
                    initialDelay: 0,
                    requiresNetwork: true,
                    conflictPolicy: .replace
                )
            )
        }
    }
    
    private func handleRefreshTask() async throws -> AirshipWorkResult {
        guard self.privacyManager.isAnyFeatureEnabled() else {
            return .success
        }

        var success = false
        defer {
            self.refreshFinished(result: success)
        }

        let lastModified = self.isLastMetadataCurrent() ? self.lastModified : nil
        let locale = self.localeManager.currentLocale
        
        let response = try await self.apiClient.fetchRemoteData(
            locale: locale,
            randomValue: self.randomValue,
            lastModified: lastModified
        )

        AirshipLogger.debug(
            "Remote data status code: \(response.statusCode)"
        )

        AirshipLogger.trace(
            "Remote data response \(response)"
        )

        guard
            response.isSuccess || response.statusCode == 304
        else {
            // Prevents retrying on client error
            return response.isServerError ? .failure : .success
        }

        var payloads: [RemoteDataPayload]?

        if response.isSuccess, let remoteData = response.result {
            payloads = remoteData.payloads ?? []
            try await self.remoteDataStore.overwriteCachedRemoteData(
                payloads ?? []
            )
            self.lastMetadata = remoteData.metadata
            self.lastModified = remoteData.lastModified
        }
        self.updatedSinceLastForeground.value = true
        
        self.lastRefreshTime = self.date.now
        self.lastAppVersion = AirshipUtils.bundleShortVersionString()
        success = true

        if let payloads = payloads {
            self.updateSubject.send(payloads)
        }

        return .success
    }

    private func refreshFinished(result: Bool) {
        self.refreshLock.sync {
            for completionHandler in self.refreshCompletionHandlers {
                if let handler = completionHandler {
                    handler(result)
                }
            }
            self.refreshCompletionHandlers.removeAll()
            self.isRefreshing = false
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

    public func refresh(force: Bool) async -> Bool {
        let state = await self.appStateTracker.state
        if (!(force || self.shouldRefresh(state: state))) {
            // Already up to date
            return true
        } else if self.networkMonitor.isConnected {
            return await withUnsafeContinuation { continuation in
                self.refreshLock.sync {
                    self.refreshCompletionHandlers.append({ result in
                        continuation.resume(returning: result)
                    })
                    
                    if !isRefreshing {
                        enqueueRefreshTask()
                    }
                }
            }
        } else {
            return false
        }
    }

    private func isLastAppVersionCurrent() -> Bool {
        let lastAppRefreshVersion = self.dataStore.string(
            forKey: RemoteDataManager.lastRefreshAppVersionKey
        )
        let currentAppVersion = AirshipUtils.bundleShortVersionString()
        return lastAppRefreshVersion == currentAppVersion
    }

    private func isLastMetadataCurrent() -> Bool {
        let current = self.createMetadata(
            locale: self.localeManager.currentLocale,
            lastModified: self.lastModified
        )
        return isMetadataCurrent(current)
    }

    private func shouldRefresh(state: ApplicationState) -> Bool {
        guard self.privacyManager.isAnyFeatureEnabled(),
            state == .active
        else {
            return false
        }

        guard self.isLastAppVersionCurrent(),
            self.isLastMetadataCurrent()
        else {
            return true
        }

        var result = false
        self.refreshLock.sync {
            if !self.updatedSinceLastForeground.value {
                let timeSinceLastRefresh = self.date.now.timeIntervalSince(
                    self.lastRefreshTime
                )
                if timeSinceLastRefresh >= self.remoteDataRefreshInterval {
                    result = true
                }
            }
        }
        
        return result
    }

    public func current(types: [String]) -> Future<[RemoteDataPayload], Never> {
        return Future { promise in
            Task {
                do {
                    let predicate = AirshipCoreDataPredicate(format: "(type IN %@)", args: [types])
                    let payloads = try await self.remoteDataStore.fetchRemoteDataFromCache(predicate: predicate)
                    promise(.success(payloads))
                } catch {
                    AirshipLogger.error("Error executing fetch request \(error)")
                }
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

