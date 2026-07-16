/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable
@_spi(AirshipInternal) import AirshipCore
import Combine
import Foundation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RemoteDataTest {

    private static let RefreshTask = "RemoteData.refresh"

    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    let config = RuntimeConfig.testConfig()

    private let contactProvider: TestRemoteDataProvider = TestRemoteDataProvider(source: .contact, enabled: false)
    private let appProvider: TestRemoteDataProvider = TestRemoteDataProvider(source: .app, enabled: true)

    private let testDate: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let testContact: TestContact = TestContact()
    private let testLocaleManager: TestLocaleManager = TestLocaleManager()
    private let testWorkManager: TestWorkManager = TestWorkManager()
    private let testAppStateTracker: TestAppStateTracker = TestAppStateTracker()
    private let testTaskSleeper: TestTaskSleeper = TestTaskSleeper()
    private let remoteData: RemoteData
    private let privacyManager: TestPrivacyManager

    init() async throws {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: self.config,
            defaultEnabledFeatures: .all
        )

        self.testDate.dateOverride = Date()
        self.testLocaleManager.currentLocale =  Locale(identifier: "en-US")
        self.remoteData = RemoteData(
            config: config,
            dataStore: self.dataStore,
            localeManager: self.testLocaleManager,
            privacyManager: self.privacyManager,
            contact: self.testContact,
            providers: [self.appProvider, self.contactProvider],
            workManager: self.testWorkManager,
            date: self.testDate,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.testAppStateTracker,
            taskSleeper: self.testTaskSleeper,
            appVersion: "SomeAppVersion"
        )
        
        await self.appProvider.setStatusCallback { _, _, _ in return .upToDate }
        await self.contactProvider.setStatusCallback { _, _, _ in return .upToDate }
    }

    @Test
    func testRemoteConfigUpdatedEnqueuesRefresh() async {
        #expect(0 == testWorkManager.workRequests.count)
        self.config.updateRemoteConfig(
            RemoteConfig(
                airshipConfig: .init(
                    remoteDataURL: "someURL",
                    deviceAPIURL: "someURL",
                    analyticsURL: "someURL",
                    meteredUsageURL: "someURL"
                )
            )
        )
        await self.remoteData.serialQueue.waitForCurrentOperations()
        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    func testContactUpdateEnqueuesRefresh() {
        #expect(0 == testWorkManager.workRequests.count)
        self.testContact.contactIDUpdatesSubject.send(
            ContactIDInfo(contactID: "some id", isStable: true, namedUserID: nil)
        )
        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    func testLocaleUpdatesEnqueuesRefresh() {
        #expect(0 == testWorkManager.workRequests.count)
        notificationCenter.post(
            name: AirshipNotifications.LocaleUpdated.name
        )
        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    func testForegroundRefreshEnqueuesRefresh() {
        #expect(0 == testWorkManager.workRequests.count)
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        #expect(1 == testWorkManager.workRequests.count)

        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        #expect(1 == testWorkManager.workRequests.count)

        self.testDate.offset += self.remoteData.refreshInterval
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        #expect(2 == testWorkManager.workRequests.count)
    }

    @Test
    func testAirshipReadyEnqueuesRefresh() async {
        #expect(0 == testWorkManager.workRequests.count)
        self.remoteData.airshipReady()
        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    @MainActor
    func testForegroundStartsPolling() async {
        await self.testTaskSleeper.pause()
        self.testAppStateTracker.currentState = .active

        notificationCenter.post(name: AppStateTracker.didTransitionToForeground)
        #expect(1 == testWorkManager.workRequests.count)

        // Polling task started → requests a sleep at the configured interval.
        await self.testTaskSleeper.waitForSleep(self.remoteData.foregroundPollingInterval)

        await self.cancelPolling()
    }

    @Test
    @MainActor
    func testAirshipReadyStartsPollingWhenForegrounded() async {
        await self.testTaskSleeper.pause()
        self.testAppStateTracker.currentState = .active

        self.remoteData.airshipReady()
        #expect(1 == testWorkManager.workRequests.count)

        await self.testTaskSleeper.waitForSleep(self.remoteData.foregroundPollingInterval)

        await self.cancelPolling()
    }

    @Test
    @MainActor
    func testAirshipReadyDoesNotStartPollingWhenBackgrounded() async {
        self.testAppStateTracker.currentState = .background

        self.remoteData.airshipReady()
        #expect(1 == testWorkManager.workRequests.count)

        for _ in 0..<5 { await Task.yield() }
        let sleeps = await self.testTaskSleeper.sleeps
        #expect(sleeps.isEmpty)
    }

    @Test
    @MainActor
    func testBackgroundStopsPolling() async {
        await self.testTaskSleeper.pause()
        self.testAppStateTracker.currentState = .active

        notificationCenter.post(name: AppStateTracker.didTransitionToForeground)
        await self.testTaskSleeper.waitForSleep(self.remoteData.foregroundPollingInterval)
        let sleepsBefore = await self.testTaskSleeper.sleeps.count

        self.testAppStateTracker.currentState = .background
        notificationCenter.post(name: AppStateTracker.didTransitionToBackground)
        await self.testTaskSleeper.resume()
        for _ in 0..<10 { await Task.yield() }

        let sleepsAfter = await self.testTaskSleeper.sleeps.count
        #expect(sleepsBefore == sleepsAfter, "no additional sleep after polling is cancelled")
        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    @MainActor
    func testForegroundPollingUsesRemoteConfigInterval() async {
        self.config.updateRemoteConfig(
            RemoteConfig(foregroundPollingIntervalMilliseconds: 30_000)
        )
        await self.remoteData.serialQueue.waitForCurrentOperations()

        await self.testTaskSleeper.pause()
        self.testAppStateTracker.currentState = .active
        notificationCenter.post(name: AppStateTracker.didTransitionToForeground)

        await self.testTaskSleeper.waitForSleep(30)

        await self.cancelPolling()
    }

    /// Cancel the polling task and release the parked sleep so the loop exits cleanly.
    @MainActor
    private func cancelPolling() async {
        notificationCenter.post(name: AppStateTracker.didTransitionToBackground)
        await self.testTaskSleeper.resume()
    }

    @Test
    func testNotifyOutdatedContact() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .contact
        )

        let expectation = AirshipTestExpectation()
        await self.contactProvider.setNotifyOutdatedCallback { @Sendable info in
            #expect(remoteDataInfo == info)
            expectation.fulfill()
            return true
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)

        await fulfillment(of: [expectation], timeout: 10)
    }

    @Test
    func testNotifyOutdatedApp() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .app
        )

        let expectation = AirshipTestExpectation()
        await self.appProvider.setNotifyOutdatedCallback { @Sendable info in
            #expect(remoteDataInfo == info)
            expectation.fulfill()
            return true
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)

        await fulfillment(of: [expectation], timeout: 10)
    }

    @Test
    func testNotifyOutdatedEnqueusRefreshTask() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .app
        )

        #expect(0 == testWorkManager.workRequests.count)

        await self.appProvider.setNotifyOutdatedCallback { _ in return false }
        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        #expect(0 == testWorkManager.workRequests.count)

        await self.appProvider.setNotifyOutdatedCallback { _ in return true }
        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    func testIsCurrentContact() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .contact
        )

        let expectation = AirshipTestExpectation()
        let testLocaleManager = self.testLocaleManager
        await self.contactProvider.setIsCurrentCallback { @Sendable locale, _, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return false
        }

        let result = await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        await fulfillment(of: [expectation], timeout: 10)

        #expect(!(result))
    }

    @Test
    func testIsCurrentApp() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .app
        )

        let expectation = AirshipTestExpectation()
        let testLocaleManager = self.testLocaleManager
        await self.appProvider.setIsCurrentCallback { @Sendable locale, _, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return true
        }

        let result = await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        await fulfillment(of: [expectation], timeout: 10)

        #expect(result)
    }

    @Test
    func testContactStatus() async {
        let expectation = AirshipTestExpectation()
        let testLocaleManager = self.testLocaleManager

        await self.contactProvider.setStatusCallback { @Sendable _, locale, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return .upToDate
        }

        let result = await self.remoteData.status(source: .contact)
        await fulfillment(of: [expectation], timeout: 10)

        #expect(.upToDate == result)
    }

    @Test
    func testAppStatus() async {
        let expectation = AirshipTestExpectation()
        let testLocaleManager = self.testLocaleManager

        await self.appProvider.setStatusCallback { @Sendable _, locale, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return .stale
        }

        let result = await self.remoteData.status(source: .app)
        await fulfillment(of: [expectation], timeout: 10)

        #expect(.stale == result)
    }

    @Test
    @MainActor
    func testContentAvailableRefresh() async {
        #expect(0 == self.testWorkManager.workRequests.count)

        let json = try! AirshipJSON.wrap([
            "com.urbanairship.remote-data.update": NSNumber(value: true)
        ])
        
        let result = await self.remoteData.receivedRemoteNotification(json)
        #expect(.newData == result)

        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    @MainActor
    func testSettingRefreshInterval() {
        #expect(self.remoteData.refreshInterval == 10)
        self.config.updateRemoteConfig(RemoteConfig(remoteDataRefreshIntervalMilliseconds: 9999 * 1000))
        #expect(self.remoteData.refreshInterval == 9999)
    }

    @Test
    func testPayloads() async {
        let contactPayloads = [
            RemoteDataTestUtils.generatePayload(
                type: "foo",
                timestamp: Date(),
                data: ["cool": "contact"],
                source: .contact
            )
        ]

        let appPayloads = [
            RemoteDataTestUtils.generatePayload(
                type: "foo",
                timestamp: Date(),
                data: ["cool": "app"],
                source: .app
            ),
            RemoteDataTestUtils.generatePayload(
                type: "bar",
                timestamp: Date(),
                data: ["not cool": "app"],
                source: .app
            )
        ]

        await self.contactProvider.setPayloads(contactPayloads)
        await self.appProvider.setPayloads(appPayloads)

        let barResult = await self.remoteData.payloads(types: ["bar"])
        #expect(barResult == [appPayloads[1]])

        let fooResult = await self.remoteData.payloads(types: ["foo"])
        #expect(fooResult == [appPayloads[0], contactPayloads[0]])

        let barFooResult = await self.remoteData.payloads(types: ["bar", "foo"])
        #expect(barFooResult == [appPayloads[1], appPayloads[0], contactPayloads[0]])

        let bazResult = await self.remoteData.payloads(types: ["baz"])
        #expect(bazResult == [])
    }

    @Test
    func testPayloadUpdates() async {
        await self.contactProvider.setRefreshCallback { @Sendable _, _, _ in
            return .newData
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, _, _ in
            return .newData
        }

        let expectation = AirshipTestExpectation()
        expectation.expectedFulfillmentCount = 2   // baseline + ≥1 refresh

        let first = AirshipTestExpectation()
        let isFirst = AirshipAtomicValue<Bool>(false)

        let subscription = self.remoteData.publisher(types: ["foo"])
            .sink { payloads in
                if isFirst.compareAndSet(expected: false, value: true) {
                    first.fulfill()
                }
                expectation.fulfill()
                #expect(payloads.isEmpty)
            }

        await fulfillment(of: [first], timeout: 10)
        await self.launchRefreshTask()
        await fulfillment(of: [expectation], timeout: 10)
        subscription.cancel()
    }


    @Test
    func testForceRefresh() async {
        await self.contactProvider.setRefreshCallback { @Sendable _, _, _ in
            return .newData
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, _, _ in
            return .skipped
        }

        self.testWorkManager.autoLaunchRequests = true
        let refreshFinished = AirshipTestExpectation(description: "refresh finished")

        let remoteData = self.remoteData
        Task.detached {
            await remoteData.forceRefresh()
            refreshFinished.fulfill()
        }

        await fulfillment(of: [refreshFinished])

        #expect(1 == testWorkManager.workRequests.count)
    }

    @Test
    func testRefreshProviders() async {
        let expectation = AirshipTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let testLocaleManager = self.testLocaleManager

        await self.contactProvider.setRefreshCallback { @Sendable _, locale, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return .skipped
        }

        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return .newData
        }
        

        let result = await self.launchRefreshTask()
        await fulfillment(of: [expectation], timeout: 10)

        #expect(result == .success)
    }

    @Test
    func testRefreshProviderFailed() async {
        let expectation = AirshipTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let testLocaleManager = self.testLocaleManager

        await self.contactProvider.setRefreshCallback { @Sendable _, locale, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return .failed
        }

        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            #expect(testLocaleManager.currentLocale == locale)
            expectation.fulfill()
            return .newData
        }

        let result = await self.launchRefreshTask()
        await fulfillment(of: [expectation], timeout: 10)

        #expect(result == .failure)
    }

    @Test
    @MainActor
    func testChangeTokenBgPush() async {
        let changeToken = AirshipAtomicValue<String?>(nil)

        // Capture the change token
        let testLocaleManager = self.testLocaleManager
        await self.contactProvider.setRefreshCallback { @Sendable change, locale, _ in
            changeToken.set(change)
            #expect(testLocaleManager.currentLocale == locale)
            return .failed
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            return .newData
        }

        await self.launchRefreshTask()
        #expect(changeToken.value != nil)

        let last = changeToken.value
        await self.launchRefreshTask()
        #expect(last == changeToken.value)

        // Send bg push
        _ = await self.remoteData.receivedRemoteNotification(
            try! AirshipJSON.wrap(
                [
                    "com.urbanairship.remote-data.update": NSNumber(value: true)
                ]
            )
        )

        await self.launchRefreshTask()
        #expect(last != changeToken.value)
    }

    @Test
    @MainActor
    func testChangeTokenAppForeground() async {
        let changeToken = AirshipAtomicValue<String?>(nil)

        // Capture the change token
        let testLocaleManager = self.testLocaleManager
        await self.contactProvider.setRefreshCallback { @Sendable change, locale, _ in
            changeToken.set(change)
            #expect(testLocaleManager.currentLocale == locale)
            return .failed
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            return .newData
        }

        await self.launchRefreshTask()
        #expect(changeToken.value != nil)

        var last = changeToken.value

        // Foreground
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )

        await self.launchRefreshTask()
        #expect(last != changeToken.value)

        // Foreground again without changing clock
        last = changeToken.value
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        await self.launchRefreshTask()
        // Should not change
        #expect(last == changeToken.value)

        // Foreground after refresh interval
        self.testDate.offset += self.remoteData.refreshInterval
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )

        await self.launchRefreshTask()
        #expect(last != changeToken.value)
    }

    @Test
    @MainActor
    func testWaitForRefresh() async {
        await self.contactProvider.setRefreshCallback{ _, _, _ in
            return .failed
        }

        await self.appProvider.setRefreshCallback{ _, _, _ in
            return .failed
        }

        let finished = AirshipMainActorValue(false)
        let task = Task {
            await self.remoteData.waitRefresh(source: .app)
            finished.set(true)
        }

        await self.launchRefreshTask()
        var isFinished = finished.value
        #expect(!(isFinished))

        await self.appProvider.setRefreshCallback{ _, _, _ in
            return .newData
        }

        await self.launchRefreshTask()
        await task.value
        isFinished = finished.value
        #expect(isFinished)
    }

    @discardableResult
    private func launchRefreshTask() async -> AirshipWorkResult {
        return try! await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataTest.RefreshTask
            )
        )!
    }
}

fileprivate actor TestRemoteDataProvider: RemoteDataProviderProtocol {
    private var statusCallback: (@Sendable (String, Locale, Int) async -> RemoteDataSourceStatus)?
    func setStatusCallback(callback: @escaping @Sendable (String, Locale, Int) async -> RemoteDataSourceStatus) {
        self.statusCallback = callback
    }

    func status(changeToken: String, locale: Locale, randomeValue: Int) async -> RemoteDataSourceStatus {
        return await self.statusCallback!(changeToken, locale, randomeValue)
    }

    let source: RemoteDataSource

    private var payloads: [RemoteDataPayload] = []
    var enabled: Bool

    private var notifyOutdatedCallback: (@Sendable (RemoteDataInfo) -> Bool)?
    func setNotifyOutdatedCallback(callback: @escaping @Sendable (RemoteDataInfo) -> Bool) {
        self.notifyOutdatedCallback = callback
    }

    private var isCurrentCallback: (@Sendable (Locale, Int, RemoteDataInfo) async -> Bool)?
    func setIsCurrentCallback(callback: @escaping @Sendable (Locale, Int, RemoteDataInfo) async -> Bool) {
        self.isCurrentCallback = callback
    }

    private var refreshCallback: (@Sendable (String, Locale, Int) async -> RemoteDataRefreshResult)?
    func setRefreshCallback(callback: @escaping @Sendable (String, Locale, Int) async -> RemoteDataRefreshResult) {
        self.refreshCallback = callback
    }

    init(source: RemoteDataSource, enabled: Bool) {
        self.source = source
        self.enabled = enabled
    }

    func setPayloads(_ payloads: [RemoteDataPayload]) {
        self.payloads = payloads
    }

    func payloads(types: [String]) async -> [RemoteDataPayload] {
        return payloads.filter { types.contains($0.type) }.sortedByType(types)
    }

    func notifyOutdated(remoteDataInfo: RemoteDataInfo) -> Bool {
        return self.notifyOutdatedCallback!(remoteDataInfo)
    }

    func isCurrent(locale: Locale, randomeValue: Int, remoteDataInfo: RemoteDataInfo) async -> Bool {
       return await self.isCurrentCallback!(locale, randomeValue, remoteDataInfo)
    }

    func refresh(changeToken: String, locale: Locale, randomeValue: Int) async -> RemoteDataRefreshResult {
        return await self.refreshCallback!(changeToken, locale, randomeValue)
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        guard self.enabled != enabled else {
            return false
        }

        self.enabled = enabled
        return true
    }
}
