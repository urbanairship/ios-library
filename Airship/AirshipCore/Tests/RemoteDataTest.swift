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
    lazy var privacyManager: AirshipPrivacyManager = {
        AirshipPrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all)
    }()

    override func setUp() async throws {
        self.config = RuntimeConfig(
            config: AirshipConfig.config(),
            dataStore: dataStore
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
        notificationCenter.post(
            name: RuntimeConfig.configUpdatedEvent
        )
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testContactUpdateEnqueuesRefresh() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        self.testContact.contactIDUpdatesSubject.send(
            ContactIDInfo(contactID: "some id", isStable: true)
        )
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testLocaleUpdatesEnqueuesRefresh() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        notificationCenter.post(
            name: AirshipLocaleManager.localeUpdatedEvent
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

        self.testDate.offset += self.remoteData.remoteDataRefreshInterval
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
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)

        await self.fulfillmentCompat(of: [expectation], timeout: 10)
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
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)

        await self.fulfillmentCompat(of: [expectation], timeout: 10)
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
        await self.fulfillmentCompat(of: [expectation], timeout: 10)

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
        await self.fulfillmentCompat(of: [expectation], timeout: 10)

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
        await self.fulfillmentCompat(of: [expectation], timeout: 10)

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
        await self.fulfillmentCompat(of: [expectation], timeout: 10)

        XCTAssertEqual(.stale, result)
    }

    func testContentAvailableRefresh() {
        XCTAssertEqual(0, self.testWorkManager.workRequests.count)

        let expectation = self.expectation(description: "Callback called")

        self.remoteData.receivedRemoteNotification([
            "com.urbanairship.remote-data.update": NSNumber(value: true)
        ], completionHandler: { result in
            XCTAssertEqual(.newData, result)
            expectation.fulfill()
        })

        waitForExpectations(timeout: testExpectationTimeOut)
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testSettingRefreshInterval() {
        XCTAssertEqual(self.remoteData.remoteDataRefreshInterval, 10)
        self.remoteData.remoteDataRefreshInterval = 9999
        XCTAssertEqual(self.remoteData.remoteDataRefreshInterval, 9999)
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
        let subscription = self.remoteData.publisher(types: ["foo"])
            .sink { payloads in
                expectation.fulfill()
                XCTAssertTrue(payloads.isEmpty)
            }

        await self.launchRefreshTask()
        await self.fulfillmentCompat(of: [expectation], timeout: 10)
        subscription.cancel()
    }


    func testRefreshSuccess() async {
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
            let result = await remoteData?.refresh()
            XCTAssertTrue(result == true)
            refreshFinished.fulfill()
        }

        await self.fulfillmentCompat(of: [refreshFinished])

        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testRefreshFailed() async {
        await self.contactProvider.setRefreshCallback { @Sendable _, _, _ in
            return .failed
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, _, _ in
            return .newData
        }

        self.testWorkManager.autoLaunchRequests = true
        let refreshFinished = expectation(description: "refresh finished")
        let remoteData = self.remoteData
        Task.detached {
            let result = await remoteData!.refresh()
            XCTAssertFalse(result)
            refreshFinished.fulfill()
        }

        await self.fulfillmentCompat(of: [refreshFinished])
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testRefreshSource() async {
        await self.contactProvider.setRefreshCallback { @Sendable _, _, _ in
            return .failed
        }
        await self.appProvider.setRefreshCallback{ @Sendable _, _, _ in
            return .newData
        }

        self.testWorkManager.autoLaunchRequests = true
        let refreshFinished = expectation(description: "refresh finished")
        let remoteData = self.remoteData
        Task.detached {
            let result = await remoteData!.refresh(source: .app)
            XCTAssertTrue(result)
            refreshFinished.fulfill()
        }

        await self.launchRefreshTask()

        await self.fulfillmentCompat(of: [refreshFinished])

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
        await self.fulfillmentCompat(of: [expectation], timeout: 10)

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
        await self.fulfillmentCompat(of: [expectation], timeout: 10)

        XCTAssertEqual(result, .failure)
    }

    func testChangeTokenBgPush() async {
        let changeToken = Atomic<String?>(nil)

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
        self.remoteData.receivedRemoteNotification(
            [
                "com.urbanairship.remote-data.update": NSNumber(value: true)
            ]
        ) { _ in }

        await self.launchRefreshTask()
        XCTAssertNotEqual(last, changeToken.value)
    }

    func testChangeTokenAppForeground() async {
        let changeToken = Atomic<String?>(nil)

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
        self.testDate.offset += self.remoteData.remoteDataRefreshInterval
        notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground
        )

        await self.launchRefreshTask()
        XCTAssertNotEqual(last, changeToken.value)
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

    private var notifyOutdatedCallback: ((RemoteDataInfo) -> Void)?
    func setNotifyOutdatedCallback(callback: @escaping (RemoteDataInfo) -> Void) {
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

    func notifyOutdated(remoteDataInfo: RemoteDataInfo) {
        self.notifyOutdatedCallback!(remoteDataInfo)
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
