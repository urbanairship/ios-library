/* Copyright Airship and Contributors */

@preconcurrency
import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// NOTE: For internal use only. :nodoc:
final class RemoteData: AirshipComponent, RemoteDataProtocol {
    fileprivate enum RefreshStatus: Sendable {
        case none
        case success
        case failed
    }

    static let refreshTaskID = "RemoteData.refresh"
    static let defaultRefreshInterval: TimeInterval = 10
    static let refreshRemoteDataPushPayloadKey = "com.urbanairship.remote-data.update"

    // Datastore keys
    private static let randomValueKey = "remotedata.randomValue"
    private static let changeTokenKey = "remotedata.CHANGE_TOKEN"

    private let config: RuntimeConfig
    private let providers: [any RemoteDataProviderProtocol]
    private let dataStore: PreferenceDataStore
    private let date: any AirshipDateProtocol
    private let localeManager: any AirshipLocaleManagerProtocol
    private let workManager: any AirshipWorkManagerProtocol
    private let privacyManager: any InternalAirshipPrivacyManagerProtocol
    private let appVersion: String
    private let statusUpdates: AirshipAsyncChannel<[RemoteDataSource: RemoteDataSourceStatus]> = AirshipAsyncChannel()
    private let currentSourceStatus: AirshipAtomicValue<[RemoteDataSource: RemoteDataSourceStatus]> = .init([:])

    private let refreshResultSubject = PassthroughSubject<(source: RemoteDataSource, result: RemoteDataRefreshResult), Never>()
    private let refreshStatusSubjectMap: [RemoteDataSource: CurrentValueSubject<RefreshStatus, Never>]

    private let lastActiveRefreshDate: AirshipMainActorValue<Date> = AirshipMainActorValue(Date.distantPast)
    private let changeTokenLock: AirshipLock = AirshipLock()
    private let contactSubscription: AirshipUnsafeSendableWrapper<AnyCancellable?> = AirshipUnsafeSendableWrapper(nil)
    let serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()

    private var randomValue: Int {
        if let value = self.dataStore.object(forKey: RemoteData.randomValueKey) as? Int {
            return value
        }

        let randomValue = Int.random(in: 0...9999)
        self.dataStore.setObject(randomValue, forKey: RemoteData.randomValueKey)
        return randomValue
    }

    @MainActor
    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        localeManager: any AirshipLocaleManagerProtocol,
        privacyManager: any InternalAirshipPrivacyManagerProtocol,
        contact: any InternalAirshipContactProtocol
    ) {
        let client = RemoteDataAPIClient(config: config)
        self.init(
            config: config,
            dataStore: dataStore,
            localeManager: localeManager,
            privacyManager: privacyManager,
            contact: contact,
            providers: [

                // App
                RemoteDataProvider(
                    dataStore: dataStore,
                    delegate: AppRemoteDataProviderDelegate(
                        config: config,
                        apiClient: client
                    )
                ),

                // Contact
                RemoteDataProvider(
                    dataStore: dataStore,
                    delegate: ContactRemoteDataProviderDelegate(
                        config: config,
                        apiClient: client,
                        contact: contact
                    ),
                    defaultEnabled: false
                )
            ]
        )
    }

    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        localeManager: any AirshipLocaleManagerProtocol,
        privacyManager: any InternalAirshipPrivacyManagerProtocol,
        contact: any InternalAirshipContactProtocol,
        providers: [any RemoteDataProviderProtocol],
        workManager: any AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        date: any AirshipDateProtocol = AirshipDate.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? ""

    ) {
        self.config = config
        self.dataStore = dataStore
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.providers = providers
        self.workManager = workManager
        self.date = date
        self.appVersion = appVersion

        self.refreshStatusSubjectMap = self.providers.reduce(
            into: [RemoteDataSource: CurrentValueSubject<RefreshStatus, Never>]()
        ) {
            $0[$1.source] = CurrentValueSubject(.none)
        }

        self.contactSubscription.value = contact.contactIDUpdates
            .map { $0.contactID }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.enqueueRefreshTask()
            }

        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueRefreshTask),
            name: AirshipNotifications.LocaleUpdated.name,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueRefreshTask),
            name: AirshipNotifications.PrivacyManagerUpdated.name,
            object: nil
        )
        
        self.workManager.registerWorker(
            RemoteData.refreshTaskID
        ) { [weak self] _ in
            return try await self?.handleRefreshTask() ?? .success
        }

        onConfigUpdated(config.remoteConfig, isUpdate: false)
        config.addRemoteConfigListener(notifyCurrent: false) { [weak self] _, new in
            self?.onConfigUpdated(new, isUpdate: true)
        }
        updateChangeToken()
    }

    private func onConfigUpdated(_ remoteConfig: RemoteConfig?, isUpdate: Bool) {
        self.serialQueue.enqueue { [providers] in
            let provider = providers.first { $0.source == .contact }
            let updated = await provider?.setEnabled(remoteConfig?.fetchContactRemoteData ?? false)
            if (isUpdate || updated == true) {
                await self.enqueueRefreshTask()
            }
        }
    }

    public func status(
        source: RemoteDataSource
    ) async -> RemoteDataSourceStatus {
        let result = await sourceStatus(source: source)
        await recordStatusFor([source])
        return result
    }
    
    private func sourceStatus(
        source: RemoteDataSource
    ) async -> RemoteDataSourceStatus {
        return if let provider = providers.first(where: { $0.source == source }) {
            await provider.status(
                changeToken: self.changeToken,
                locale: self.localeManager.currentLocale,
                randomeValue: self.randomValue
            )
        } else {
            .outOfDate
        }
    }
    
    private func recordStatusFor(_ sources: [RemoteDataSource]) async {
        var updates: [RemoteDataSource: RemoteDataSourceStatus] = self.currentSourceStatus.value
        
        for source in sources {
            updates[source] = await sourceStatus(source: source)
        }
        
        guard updates != self.currentSourceStatus.value else {
            return
        }
        
        self.currentSourceStatus.update(onModify: { _ in updates })
        await statusUpdates.send(updates)
    }

    public func isCurrent(
        remoteDataInfo: RemoteDataInfo
    ) async -> Bool {
        let locale = localeManager.currentLocale
        for provider in self.providers {
            if (provider.source == remoteDataInfo.source) {
                return await provider.isCurrent(
                    locale: locale,
                    randomeValue: randomValue,
                    remoteDataInfo: remoteDataInfo
                )
            }
        }

        AirshipLogger.error("No remote data handler for \(remoteDataInfo.source)")
        return false
    }

    public func notifyOutdated(remoteDataInfo: RemoteDataInfo) async {
        for provider in self.providers {
            if (provider.source == remoteDataInfo.source) {
                if (await provider.notifyOutdated(remoteDataInfo: remoteDataInfo)) {
                    await enqueueRefreshTask()
                }
                return
            }
        }
    }
    
    @MainActor
    public func statusUpdates<T:Sendable>(
        sources: [RemoteDataSource],
        map: @escaping (@Sendable (_ statuses: [RemoteDataSource: RemoteDataSourceStatus]) -> T)
    ) async -> AsyncStream<T> {
        
        return AsyncStream { [weak self] continuation in
            let task = Task { [weak self] in
                
                await self?.recordStatusFor(sources)
                
                let isInSource: ((RemoteDataSource, RemoteDataSourceStatus)) -> Bool = {
                    sources.contains($0.0)
                }
                
                let current = self?.currentSourceStatus.value.filter(isInSource) ?? [:]
                let mappedStatuses = map(current)
                continuation.yield(mappedStatuses)
                
                if let updates = await self?.statusUpdates.makeStream() {
                    for await item in updates {
                        let filtered = item.filter(isInSource)
                        continuation.yield(map(filtered))
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    @MainActor
    public func airshipReady() {
        self.enqueueRefreshTask()
    }

    var refreshInterval: TimeInterval {
        return self.config.remoteConfig.remoteDataRefreshInterval ?? Self.defaultRefreshInterval
    }

    @objc
    @MainActor
    private func applicationDidForeground() {
        let now = self.date.now

        let nextUpdate = self.lastActiveRefreshDate.value.advanced(by: 
            self.refreshInterval
        )

        if now >= nextUpdate {
            updateChangeToken()
            self.enqueueRefreshTask()
            self.lastActiveRefreshDate.set(now)
        }
    }

    @objc
    @MainActor
    private func enqueueRefreshTask() {
        self.refreshStatusSubjectMap.values.forEach { subject in
            subject.sendMainActor(.none)
        }
        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: RemoteData.refreshTaskID,
                initialDelay: 0,
                requiresNetwork: true,
                conflictPolicy: .replace
            )
        )
    }

    private func updateChangeToken() {
        self.changeTokenLock.sync {
            self.dataStore.setObject(UUID().uuidString, forKey: RemoteData.changeTokenKey)
        }
    }

    /// The change token is just an easy way to know when we need to require an actual update vs checking the remote-data info if it has
    /// changed. We will create a new token on foreground (if its passed the refresh interval) or background push.
    private var changeToken: String {
        var token: String!
        self.changeTokenLock.sync {
            let fromStore = self.dataStore.string(forKey: RemoteData.changeTokenKey)
            if let fromStore = fromStore {
                token = fromStore
            } else {
                token = UUID().uuidString
                self.dataStore.setObject(token, forKey: RemoteData.changeTokenKey)
            }
        }

        return token + self.appVersion
    }
    
    private func handleRefreshTask() async throws -> AirshipWorkResult {
        guard self.privacyManager.isAnyFeatureEnabled(ignoringRemoteConfig: true) else {
            for provider in providers {
                await refreshResultSubject.sendMainActor((provider.source, .skipped))
                await refreshStatusSubjectMap[provider.source]?.sendMainActor(.success)
            }
            return .success
        }

        let changeToken = self.changeToken
        let locale = self.localeManager.currentLocale
        let randomValue = self.randomValue

        let success = await withTaskGroup(
            of: (RemoteDataSource, RemoteDataRefreshResult).self
        ) { [providers, refreshResultSubject, refreshStatusSubjectMap] group in
            for provider in providers {
                group.addTask{
                    let result = await provider.refresh(
                        changeToken: changeToken,
                        locale: locale,
                        randomeValue: randomValue
                    )
                    return (provider.source, result)
                }
            }

            var success: Bool = true
            for await (source, result) in group {
                await refreshResultSubject.sendMainActor((source, result))
                if (result == .failed) {
                    success = false
                    await refreshStatusSubjectMap[source]?.sendMainActor(.failed)
                } else {
                    await refreshStatusSubjectMap[source]?.sendMainActor(.success)
                }
            }

            return success
        }
        
        await recordStatusFor(providers.map({ $0.source }))

        return success ? .success : .failure
    }

    public func forceRefresh() async {
        self.updateChangeToken()
        await enqueueRefreshTask()
        let sources = self.providers.map { $0.source }
        for source in sources {
            await self.waitRefreshAttempt(source: source)
        }
    }

    public func waitRefresh(source: RemoteDataSource) async {
        await waitRefresh(source: source, maxTime: nil)
    }

    public func waitRefresh(
        source: RemoteDataSource,
        maxTime: TimeInterval?
    ) async {
        AirshipLogger.trace("Waiting for remote data to refresh succesfully \(source)")
        await waitRefreshStatus(source: source, maxTime: maxTime) { status in
            status == .success
        }
    }

    public func waitRefreshAttempt(source: RemoteDataSource) async {
        await waitRefreshAttempt(source: source, maxTime: nil)
    }

    public func waitRefreshAttempt(
        source: RemoteDataSource,
        maxTime: TimeInterval?
    ) async {
        AirshipLogger.trace("Waiting for remote refresh attempt \(source)")
        await waitRefreshStatus(source: source, maxTime: maxTime) { status in
            status != .none
        }
    }

    private func waitRefreshStatus(
        source: RemoteDataSource,
        maxTime: TimeInterval?,
        statusPredicate: @escaping @Sendable (RefreshStatus) -> Bool
    ) async {
        guard let subject = self.refreshStatusSubjectMap[source] else {
            return
        }

        let result: RefreshStatus = await withUnsafeContinuation { continuation in
            var cancellable: AnyCancellable?

            var publisher: AnyPublisher<RefreshStatus, Never> = subject.first(where: statusPredicate).eraseToAnyPublisher()

            if let maxTime = maxTime, maxTime > 0.0 {
                publisher = Publishers.Merge(
                    Just(.none).delay(
                        for: .seconds(maxTime),
                        scheduler: RunLoop.main
                    ),
                    publisher
                ).eraseToAnyPublisher()
            }

            cancellable = publisher.first()
                .sink { result in
                    continuation.resume(returning: result)
                    cancellable?.cancel()
                }
        }

        AirshipLogger.trace("Remote data refresh: \(source), status: \(result)")
    }
    
    public func payloads(types: [String]) async -> [RemoteDataPayload] {
        var payloads: [RemoteDataPayload] = []
        for provider in self.providers {
            payloads += await provider.payloads(types: types)
        }
        return payloads.sortedByType(types)
    }

    private func payloadsFuture(types: [String]) -> Future<[RemoteDataPayload], Never> {
        return Future { promise in
            let wrapped = SendablePromise(promise: promise)
            Task {
                let payloads = await self.payloads(types: types)
                wrapped.promise(.success(payloads))
            }
        }
    }

    public func publisher(
        types: [String]
    ) -> AnyPublisher<[RemoteDataPayload], Never> {
        // We use the refresh subject to know when to update
        // the current values by listening for a `newData` result
        return self.refreshResultSubject
            .filter { result in
                result.result == .newData
            }
            .flatMap { _ in
                // Fetch data
                self.payloadsFuture(types: types)
            }
            .prepend(
                // Prepend current data
                self.payloadsFuture(types: types)
            )
            .eraseToAnyPublisher()
    }
}

extension RemoteData: AirshipPushableComponent {
    public func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UABackgroundFetchResult {

        guard
            let userInfo = notification.unwrapAsUserInfo(),
            userInfo[RemoteData.refreshRemoteDataPushPayloadKey] != nil
        else {
            return .noData
        }
        
        self.updateChangeToken()
        self.enqueueRefreshTask()
        return .newData
    }


#if !os(tvOS)
    public func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        // no-op
    }
#endif
}




extension Sequence where Iterator.Element == RemoteDataPayload {
    func sortedByType(_ types: [String]) -> [Iterator.Element] {
        return self.sorted { first, second in
            let firstIndex = types.firstIndex(of: first.type) ?? 0
            let secondIndex = types.firstIndex(of: second.type) ?? 0
            return firstIndex < secondIndex
        }
    }
}

fileprivate struct SendablePromise<O, E>: @unchecked Sendable where E : Error {
    let promise: Future<O,E>.Promise
}
