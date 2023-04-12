/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataManagerTest: AirshipBaseTest {

    private static let RefreshTask = "RemoteDataManager.refresh"

    var testAPIClient = TestRemoteDataAPIClient()
    var requestURL = URL(string: "some-url")
    var testNetworkMonitor = TestNetworkMonitor()
    var testStore = RemoteDataStore(storeName: NSUUID().uuidString , inMemory: true)
    var testDate = UATestDate(offset: 0, dateOverride: Date())
    var notificationCenter = NotificationCenter()
    var testLocaleManager = TestLocaleManager()
    var testWorkManager = TestWorkManager()
    var remoteDataManager: RemoteDataManager!

    lazy var privacyManager: AirshipPrivacyManager = {
        AirshipPrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all)
    }()

    var testAppStateTracker = TestAppStateTracker()

    @MainActor
    override func setUpWithError() throws {

        try super.setUpWithError()

        self.testAPIClient.metdataCallback = { locale, lastModified in
            if let lastModified = lastModified {
                return ["url": self.requestURL?.absoluteString ?? "",
                        "lastModified": lastModified
                ]
            }
            return ["url": self.requestURL?.absoluteString ?? ""]
        }
        self.testLocaleManager.currentLocale =  Locale(identifier: "en-US")
        self.testAppStateTracker.currentState = .active
        self.remoteDataManager = self.createManager()

        XCTAssertEqual(1, self.testWorkManager.workRequests.count);
        self.testWorkManager.workRequests = []
    }

    @MainActor
    func createManager() -> RemoteDataManager {
        let remoteDataManager = RemoteDataManager(
            dataStore: self.dataStore,
            localeManager: self.testLocaleManager,
            privacyManager: self.privacyManager,
            apiClient: self.testAPIClient,
            remoteDataStore: self.testStore,
            workManager: self.testWorkManager,
            date: self.testDate,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.testAppStateTracker,
            networkMonitor: self.testNetworkMonitor
        )
        remoteDataManager.airshipReady()
        return remoteDataManager
    }

    func testForegroundRefresh() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testRemoteConfigUpdated() {
        XCTAssertEqual(0, testWorkManager.workRequests.count)
        notificationCenter.post(name: RuntimeConfig.configUpdatedEvent, object: nil)
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testCheckRefresh() async throws {
        XCTAssertEqual(0, self.testWorkManager.workRequests.count)
        self.remoteDataManager?.lastModified = "lastMod"

        // Set initial metadata
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ],
                "lastModified": "lastMod"
            ]
        ]
        try await updatePayloads(payloads)

        self.remoteDataManager?.remoteDataRefreshInterval = 100

        notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        XCTAssertEqual(0, testWorkManager.workRequests.count)

        // Refresh interval
        self.testDate.offset += 100
        notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testCheckRefreshMetadataChanages() async throws {
        self.remoteDataManager?.remoteDataRefreshInterval = 1000

        // Set initial metadata
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]
        try await updatePayloads(payloads)

        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        XCTAssertEqual(0, self.testWorkManager.workRequests.count)

        // change URL
        self.requestURL = URL(string: "some-other-url")

        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        XCTAssertEqual(1, self.testWorkManager.workRequests.count)
    }

    func testLocaleChangeRefresh() {
        XCTAssertEqual(0, self.testWorkManager.workRequests.count)
        self.notificationCenter.post(name: AirshipLocaleManager.localeUpdatedEvent, object: nil)
        XCTAssertEqual(1, self.testWorkManager.workRequests.count)
    }

    func testContentAvailableRefresh() {
        XCTAssertEqual(0, self.testWorkManager.workRequests.count)

        let expectation = self.expectation(description: "Callback called")

        self.remoteDataManager?.receivedRemoteNotification([
            "com.urbanairship.remote-data.update": NSNumber(value: true)
        ], completionHandler: { result in
            XCTAssertEqual(.newData, result)
            expectation.fulfill()
        })

        waitForExpectations(timeout: testExpectationTimeOut)
        XCTAssertEqual(1, testWorkManager.workRequests.count)
    }

    func testRefreshRemoteData() async throws {
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]
        try await updatePayloads(payloads)
    }

    func testRefreshRemoteData304() async {
        let updateResponse = RemoteDataResponse(
            metadata: nil,
            payloads: nil,
            lastModified: nil)

        XCTAssertEqual(0, self.testWorkManager.workRequests.count)

        self.testAPIClient.fetchData = { locale, timeStamp in
            return AirshipHTTPResponse(
                result: updateResponse,
                statusCode: 304,
                headers: [:])
        }

        let result = try? await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataManagerTest.RefreshTask
            )
        )
        XCTAssertEqual(result, .success)

    }

    func testRefreshRemoteDataClientError() async throws {
        let response = RemoteDataResponse(
            metadata: nil,
            payloads: nil,
            lastModified: nil
        )

        self.testAPIClient.fetchData = { locale, timeStamp in
            return AirshipHTTPResponse(
                result: response,
                statusCode: 400,
                headers: [:])
        }

        let result = try await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataManagerTest.RefreshTask
            )
        )
        XCTAssertEqual(result, .success)
    }

    func testRefreshNoNetwork() async {
        testNetworkMonitor.isConnectedOverride = false
        let result = await self.remoteDataManager!.refresh(force: false)
        XCTAssertFalse(result)
    }

    func testRefreshRemoteDataServerError() async throws {
        let response = RemoteDataResponse(
            metadata: nil,
            payloads: nil,
            lastModified: nil)

        self.testAPIClient.fetchData = { locale, timeStamp in
            return AirshipHTTPResponse(
                result: response,
                statusCode: 500,
                headers: [:])
        }

        let result = try? await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataManagerTest.RefreshTask
            )
        )
        XCTAssertEqual(result, .failure)
    }

    func testRefreshLastModifiedMetadataChanges() async throws {
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]
        try await updatePayloads(payloads)

        self.testAPIClient.fetchData = { locale, timeStamp in
            XCTAssertNotNil(timeStamp)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:])
        }

        var result = try? await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataManagerTest.RefreshTask
            )
        )
        XCTAssertEqual(result, .success)

        // change return URL
        self.requestURL = URL(string: "some-other-url")

        self.testAPIClient.fetchData = { locale, timeStamp in
            XCTAssertNil(timeStamp)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:])
        }

        result = try? await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataManagerTest.RefreshTask
            )
        )
        XCTAssertEqual(result, .success)
    }

    func testRefreshError() async throws {
        testAPIClient.fetchData = { locale, timeStamp in
            throw AirshipErrors.error("An error occured")
        }

        do {
            _ = try await self.testWorkManager.launchTask(
                request: AirshipWorkRequest(
                    workID: RemoteDataManagerTest.RefreshTask
                )
            )
            XCTFail("Should throw")
        } catch {
        }
    }

    func testMetadata() async throws {
        let expectedMetadata = [
            "url": self.requestURL!.absoluteString,
            "lastModified": "2018-01-01T12:00:00"
        ]

        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]
        try await updatePayloads(payloads)

        var metadata: [AnyHashable: Any]?
        let callbackCalled = expectation(description: "Callback called")

        let disposable = self.remoteDataManager?.subscribe(types: ["test"], block: { remoteDataArray in
            metadata = remoteDataArray[0].metadata
            callbackCalled.fulfill()
        })

        await waitForExpectations(timeout: testExpectationTimeOut)

        XCTAssertEqual(expectedMetadata, metadata as? [String: String])

    }

    func testSubscribe() async throws {
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]

        try await updatePayloads(payloads)

        let callbackCalled = expectation(description: "Callback called")
        var remoteData: [RemoteDataPayload]? = nil

        let disposable = self.remoteDataManager?.subscribe(types: ["test"]) { remoteDataArray in
            remoteData = remoteDataArray
            callbackCalled.fulfill()
        }

        await waitForExpectations(timeout: testExpectationTimeOut)

        XCTAssertEqual(1, (remoteData?.count ?? 0))
        let payload = remoteData?[0]
        XCTAssertEqual(payloads[0]["data"] as? [String: String], payload?.data as? [String: String])
        XCTAssertEqual("test", payload?.type)
    }


    func testUnsubscribe() async throws {
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]

        let subscription = self.remoteDataManager?.subscribe(types: ["test"]) { remoteDataArray in
            XCTFail("Should never get any data")
        }
        subscription?.dispose()
        try await updatePayloads(payloads)
    }

    func testSubscriptionUpdates() async throws {
        let callbackCalled = expectation(description: "Callback called")
        callbackCalled.expectedFulfillmentCount = 3
        var responses: [[RemoteDataPayload]] = []
        let disposable = self.remoteDataManager?.subscribe(types: ["test"]) { remoteDataArray in
            responses.append(remoteDataArray)
            callbackCalled.fulfill()
        }

        try await updatePayloads([])

        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]
        let update = [
            [
                "type": "test",
                "timestamp": "2018-01-01T12:00:00",
                "data": [
                    "super": "cool"
                ]
            ]
        ]

        try await updatePayloads(payloads)
        try await updatePayloads(update)

        await waitForExpectations(timeout: testExpectationTimeOut)

        XCTAssertEqual(3, responses.count)
        var payload = responses[1][0]
        XCTAssertEqual(payloads[0]["data"] as? [String : String], payload.data as? [String : String])
        XCTAssertEqual("test", payload.type)

        payload = responses[2][0]
        XCTAssertEqual(update[0]["data"] as? [String : String], payload.data as? [String : String])
        XCTAssertEqual("test", payload.type)
    }

    func testSubscriptionUpdatesNoChanges() async throws {
        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]

        try await updatePayloads(payloads)

        let callbackCalled = expectation(description: "Callback called")
        callbackCalled.expectedFulfillmentCount = 1
        var responses: [[RemoteDataPayload]] = []
        let disposable = self.remoteDataManager?.subscribe(types: ["test"]) { remoteDataArray in
            responses.append(remoteDataArray)
            callbackCalled.fulfill()
        }

        try await updatePayloads(payloads)

        await waitForExpectations(timeout: testExpectationTimeOut)

        XCTAssertEqual(1, responses.count)
        let payload = responses[0][0]
        XCTAssertEqual(payloads[0]["data"] as? [String : String], payload.data as? [String : String])
        XCTAssertEqual("test", payload.type)
    }

    func testSubscriptionUpdatesMetadataChanged() async throws {
        let callbackCalled = expectation(description: "Callback called")
        callbackCalled.expectedFulfillmentCount = 3
        var responses: [[RemoteDataPayload]] = []
        let disposable = self.remoteDataManager?.subscribe(types: ["test"]) { remoteDataArray in
            responses.append(remoteDataArray)
            callbackCalled.fulfill()
        }

        try await updatePayloads([])

        let payloads = [
            [
                "type": "test",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]

        try await updatePayloads(payloads)


        // change URL so metadata changes
        requestURL = URL(string: "some-other-url")

        try await updatePayloads(payloads)

        wait(for: [callbackCalled], timeout: testExpectationTimeOut)

        XCTAssertEqual(3, responses.count)
        var payload = responses[1][0]
        XCTAssertEqual(payloads[0]["data"] as? [String : String], payload.data as? [String : String])
        XCTAssertEqual("test", payload.type)

        payload = responses[2][0]
        XCTAssertEqual(payloads[0]["data"] as? [String : String], payload.data as? [String : String])
        XCTAssertEqual("test", payload.type)
    }

    func testSortUpdates() async throws {
        let payloads = [
            [
                "type": "foo",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ],
            [
                "type": "bar",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "foo": "bar"
                ]
            ]
        ]

        try await updatePayloads(payloads)

        let callbackCalled = expectation(description: "Callback called")
        var remoteData: [AnyHashable]? = nil
        let disposable = self.remoteDataManager?.subscribe(types: ["bar", "foo"]) { remoteDataArray in
            remoteData = remoteDataArray
            callbackCalled.fulfill()
        }

        await waitForExpectations(timeout: testExpectationTimeOut)

        XCTAssertEqual(2, (remoteData?.count ?? 0))
        XCTAssertEqual("bar", (remoteData?[0] as? RemoteDataPayload)?.type)
        XCTAssertEqual("foo", (remoteData?[1] as? RemoteDataPayload)?.type)
    }

    func testSettingRefreshInterval() {
        XCTAssertEqual(self.remoteDataManager?.remoteDataRefreshInterval, 10)
        self.remoteDataManager?.remoteDataRefreshInterval = 9999
        XCTAssertEqual(self.remoteDataManager?.remoteDataRefreshInterval, 9999)
    }

    func updatePayloads(_ payloads: [[String : Any]]) async throws {

        self.testAPIClient.fetchData = { locale, timestamp in
            let metadata = self.testAPIClient.metdataCallback!(locale, "2018-01-01T12:00:00")
            var parsed: [RemoteDataPayload] = []
            for payload in payloads {
                let type = payload["type"] as? String
                let timestamp = AirshipUtils.isoDateFormatterUTCWithDelimiter().date(from: payload["timestamp"] as? String ?? "")
                let data = payload["data"] as? [AnyHashable : Any]

                let remoteData = RemoteDataPayload(
                    type: type!,
                    timestamp: timestamp!,
                    data: data!,
                    metadata: metadata)

                parsed.append(remoteData)
            }

            let response = RemoteDataResponse(
                metadata: metadata,
                payloads: parsed,
                lastModified: "2018-01-01T12:00:00")

            return AirshipHTTPResponse(
                result: response,
                statusCode: 200,
                headers: [:])
        }

        let result = try? await self.testWorkManager.launchTask(
            request: AirshipWorkRequest(
                workID: RemoteDataManagerTest.RefreshTask
            )
        )
        XCTAssertEqual(result, .success)
    }

}
