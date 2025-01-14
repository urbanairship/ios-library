/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataTest: AirshipBaseTest {

    private static let RefreshTask = "RemoteData.refresh"

    private let contactProvider: TestRemoteDataProvider = TestRemoteDataProvider(source: .contact, enabled: false)
    private let appProvider: TestRemoteDataProvider = TestRemoteDataProvider(source: .app, enabled: true)

    private let testDate: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let testContact: TestContact = TestContact()
    private let testLocaleManager: TestLocaleManager = TestLocaleManager()
    private let testWorkManager: TestWorkManager = TestWorkManager()
    private var remoteData: RemoteData!
    private var privacyManager: AirshipPrivacyManager!

    override func setUp() async throws {
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: self.dataStore,
            config: self.config,
            defaultEnabledFeatures: .all
        )

        self.testDate.dateOverride = Date()
        self.testLocaleManager.currentLocale =  Locale(identifier: "en-US")
        self.remoteData = await RemoteData(
            config: config,
            dataStore: self.dataStore,
            localeManager: self.testLocaleManager,
            privacyManager: self.privacyManager,
            contact: self.testContact,
            providers: [self.appProvider, self.contactProvider],
            workManager: self.testWorkManager,
            date: self.testDate,
            notificationCenter: self.notificationCenter,
            appVersion: "SomeAppVersion"
        )
    }

    func testRemoteConfigUpdatedEnqueuesRefresh() async {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        await self.config.updateRemoteConfig(
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
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testContactUpdateEnqueuesRefresh() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        self.testContact.contactIDUpdatesSubject.send(
            ContactIDInfo(contactID: "some id", isStable: true, namedUserID: nil)
        )
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testLocaleUpdatesEnqueuesRefresh() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        notificationCenter.post(
            name: AirshipNotifications.LocaleUpdated.name
        )
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testForegroundRefreshEnqueuesRefresh() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        XCTAssertEqual(1, testWorkManager.workRequests.count)

        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        XCTAssertEqual(1, testWorkManager.workRequests.count)

        self.testDate.offset += self.remoteData.refreshInterval
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        XCTAssertEqual(2, testWorkManager.workRequests.count)
    }

    func testAirshipReadyEnqueuesRefresh() async {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        await self.remoteData.airshipReady()
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testNotifyOutdatedContact() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .contact
        )

        let expectation = XCTestExpectation()
        await self.contactProvider.setNotifyOutdatedCallback { @Sendable info in
            XCTAssertEqual(remoteDataInfo, info)
            expectation.fulfill()
            return true
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)

        await self.fulfillment(of: [expectation], timeout: 10)
    }

    func testNotifyOutdatedApp() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .app
        )

        let expectation = XCTestExpectation()
        await self.appProvider.setNotifyOutdatedCallback { @Sendable info in
            XCTAssertEqual(remoteDataInfo, info)
            expectation.fulfill()
            return true
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)

        await self.fulfillment(of: [expectation], timeout: 10)
    }

    func testNotifyOutdatedEnqueusRefreshTask() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .app
        )

        XCTAssertEqual(0, testWorkManager.workRequests.count)

        await self.appProvider.setNotifyOutdatedCallback { _ in return false }
        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        XCTAssertEqual(0, testWorkManager.workRequests.count)

        await self.appProvider.setNotifyOutdatedCallback { _ in return true }
        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testIsCurrentContact() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .contact
        )

        let expectation = XCTestExpectation()
        let testLocaleManager = self.testLocaleManager
        await self.contactProvider.setIsCurrentCallback { @Sendable locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return false
        }

        let result = await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        await self.fulfillment(of: [expectation], timeout: 10)

        XCTAssertFalse(result)
    }

    func testIsCurrentApp() async {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: nil,
            source: .app
        )

        let expectation = XCTestExpectation()
        let testLocaleManager = self.testLocaleManager
        await self.appProvider.setIsCurrentCallback { @Sendable locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return true
        }

        let result = await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        await self.fulfillment(of: [expectation], timeout: 10)

        XCTAssertTrue(result)
    }

    func testContactStatus() async {
        let expectation = XCTestExpectation()
        let testLocaleManager = self.testLocaleManager

        await self.contactProvider.setStatusCallback { @Sendable _, locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return .upToDate
        }

        let result = await self.remoteData.status(source: .contact)
        await self.fulfillment(of: [expectation], timeout: 10)

        XCTAssertEqual(.upToDate, result)
    }

    func testAppStatus() async {
        let expectation = XCTestExpectation()
        let testLocaleManager = self.testLocaleManager

        await self.appProvider.setStatusCallback { @Sendable _, locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return .stale
        }

        let result = await self.remoteData.status(source: .app)
        await self.fulfillment(of: [expectation], timeout: 10)

        XCTAssertEqual(.stale, result)
    }

    @MainActor
    func testContentAvailableRefresh() async {
        XCTAssertEqual(0, self.testWorkManager.workRequests.count)

        let json = try! AirshipJSON.wrap([
            "com.urbanairship.remote-data.update": NSNumber(value: true)
        ])
        
        let result = await self.remoteData.receivedRemoteNotification(json)
        XCTAssertEqual(.newData, result)

        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    @MainActor
    func testSettingRefreshInterval() {
        XCTAssertEqual(self.remoteData.refreshInterval, 10)
        self.config.updateRemoteConfig(RemoteConfig(remoteDataRefreshIntervalMilliseconds: 9999 * 1000))
        XCTAssertEqual(self.remoteData.refreshInterval, 9999)
    }

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
        XCTAssertEqual(barResult, [appPayloads[1]])

        let fooResult = await self.remoteData.payloads(types: ["foo"])
        XCTAssertEqual(fooResult, [appPayloads[0], contactPayloads[0]])

        let barFooResult = await self.remoteData.payloads(types: ["bar", "foo"])
        XCTAssertEqual(barFooResult, [appPayloads[1], appPayloads[0], contactPayloads[0]])

        let bazResult = await self.remoteData.payloads(types: ["baz"])
        XCTAssertEqual(bazResult, [])
    }

    func testPayloadUpdates() async {
        await self.contactProvider.setRefreshCallback { @Sendable _, _, _ in
            return .newData
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, _, _ in
            return .newData
        }

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 3

        let first = XCTestExpectation()
        let isFirst = AirshipAtomicValue<Bool>(false)

        let subscription = self.remoteData.publisher(types: ["foo"])
            .sink { payloads in
                if isFirst.compareAndSet(expected: false, value: true) {
                    first.fulfill()
                }
                expectation.fulfill()
                XCTAssertTrue(payloads.isEmpty)
            }

        await self.fulfillment(of: [first], timeout: 10)
        await self.launchRefreshTask()
        await self.fulfillment(of: [expectation], timeout: 10)
        subscription.cancel()
    }


    func testForceRefresh() async {
        await self.contactProvider.setRefreshCallback { @Sendable _, _, _ in
            return .newData
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, _, _ in
            return .skipped
        }

        self.testWorkManager.autoLaunchRequests = true
        let refreshFinished = expectation(description: "refresh finished")

        let remoteData = self.remoteData
        Task.detached {
            await remoteData?.forceRefresh()
            refreshFinished.fulfill()
        }

        await self.fulfillment(of: [refreshFinished])

        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testRefreshProviders() async {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let testLocaleManager = self.testLocaleManager

        await self.contactProvider.setRefreshCallback { @Sendable _, locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return .skipped
        }

        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return .newData
        }
        

        let result = await self.launchRefreshTask()
        await self.fulfillment(of: [expectation], timeout: 10)

        XCTAssertEqual(result, .success)
    }

    func testRefreshProviderFailed() async {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let testLocaleManager = self.testLocaleManager

        await self.contactProvider.setRefreshCallback { @Sendable _, locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return .failed
        }

        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            expectation.fulfill()
            return .newData
        }

        let result = await self.launchRefreshTask()
        await self.fulfillment(of: [expectation], timeout: 10)

        XCTAssertEqual(result, .failure)
    }

    @MainActor
    func testChangeTokenBgPush() async {
        let changeToken = AirshipAtomicValue<String?>(nil)

        // Capture the change token
        let testLocaleManager = self.testLocaleManager
        await self.contactProvider.setRefreshCallback { @Sendable change, locale, _ in
            changeToken.value = change
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            return .failed
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            return .newData
        }

        await self.launchRefreshTask()
        XCTAssertNotNil(changeToken.value)

        let last = changeToken.value
        await self.launchRefreshTask()
        XCTAssertEqual(last, changeToken.value)

        // Send bg push
        _ = await self.remoteData.receivedRemoteNotification(
            try! AirshipJSON.wrap(
                [
                    "com.urbanairship.remote-data.update": NSNumber(value: true)
                ]
            )
        )

        await self.launchRefreshTask()
        XCTAssertNotEqual(last, changeToken.value)
    }

    @MainActor
    func testChangeTokenAppForeground() async {
        let changeToken = AirshipAtomicValue<String?>(nil)

        // Capture the change token
        let testLocaleManager = self.testLocaleManager
        await self.contactProvider.setRefreshCallback { @Sendable change, locale, _ in
            changeToken.value = change
            XCTAssertEqual(testLocaleManager.currentLocale, locale)
            return .failed
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, locale, _ in
            return .newData
        }
        await self.launchRefreshTask()
        XCTAssertNotNil(changeToken.value)

        var last = changeToken.value

        // Foreground
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )

        await self.launchRefreshTask()
        XCTAssertNotEqual(last, changeToken.value)

        // Foreground again without changing clock
        last = changeToken.value
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )
        await self.launchRefreshTask()
        // Should not change
        XCTAssertEqual(last, changeToken.value)

        // Foreground after refresh interval
        self.testDate.offset += self.remoteData.refreshInterval
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )

        await self.launchRefreshTask()
        XCTAssertNotEqual(last, changeToken.value)
    }

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
        XCTAssertFalse(isFinished)

        await self.appProvider.setRefreshCallback{ _, _, _ in
            return .newData
        }

        await self.launchRefreshTask()
        await task.value
        isFinished = finished.value
        XCTAssertTrue(isFinished)
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
    private var statusCallback: ((String, Locale, Int) async -> RemoteDataSourceStatus)?
    func setStatusCallback(callback: @escaping (String, Locale, Int) async -> RemoteDataSourceStatus) {
        self.statusCallback = callback
    }

    func status(changeToken: String, locale: Locale, randomeValue: Int) async -> RemoteDataSourceStatus {
        return await self.statusCallback!(changeToken, locale, randomeValue)
    }

    let source: RemoteDataSource

    private var payloads: [RemoteDataPayload] = []
    var enabled: Bool

    private var notifyOutdatedCallback: ((RemoteDataInfo) -> Bool)?
    func setNotifyOutdatedCallback(callback: @escaping (RemoteDataInfo) -> Bool) {
        self.notifyOutdatedCallback = callback
    }

    private var isCurrentCallback: ((Locale, Int) async -> Bool)?
    func setIsCurrentCallback(callback: @escaping (Locale, Int) async -> Bool) {
        self.isCurrentCallback = callback
    }

    private var refreshCallback: ((String, Locale, Int) async -> RemoteDataRefreshResult)?
    func setRefreshCallback(callback: @escaping (String, Locale, Int) async -> RemoteDataRefreshResult) {
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

    func isCurrent(locale: Locale, randomeValue: Int) async -> Bool {
       return await self.isCurrentCallback!(locale, randomeValue)
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
