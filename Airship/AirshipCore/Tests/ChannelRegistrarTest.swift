/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ChannelRegistrarTest: XCTestCase {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let client = TestChannelRegistrationClient()
    private let delegate = TestChannelRegistrarDelegate()
    private let date = UATestDate()
    private let taskManager = TestTaskManager()
    private let dispatcher = TestDispatcher()
    private let appStateTracker = AppStateTracker()

    private var channelRegistrar: ChannelRegistrar!

    override func setUpWithError() throws {
        self.channelRegistrar = ChannelRegistrar(
            dataStore: self.dataStore,
            channelAPIClient: self.client,
            date: self.date,
            dispatcher: self.dispatcher,
            taskManager: self.taskManager,
            appStateTracker: self.appStateTracker
        )

        self.client.defaultCallback = { method in
            XCTFail("Method \(method) called unexpectedly")
        }

        channelRegistrar.delegate = self.delegate
    }

    func testRegister() throws {
        XCTAssertEqual(0, self.taskManager.enqueuedRequestsCount)

        self.channelRegistrar.register(forcefully: false)

        XCTAssertEqual(1, self.taskManager.enqueuedRequestsCount)

        let extras = ["forcefully": false]
        let options = TaskRequestOptions(
            conflictPolicy: .keep,
            requiresNetwork: true,
            extras: extras
        )

        let task = self.taskManager.enqueuedRequests[0]
        XCTAssertEqual("UAChannelRegistrar.registration", task.taskID)
        XCTAssertEqual(options, task.options)
        XCTAssertEqual(0, task.minDelay)
    }

    func testRegisterForcefully() throws {
        XCTAssertEqual(0, self.taskManager.enqueuedRequestsCount)

        self.channelRegistrar.register(forcefully: true)

        XCTAssertEqual(1, self.taskManager.enqueuedRequestsCount)

        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": true]
        )

        let task = self.taskManager.enqueuedRequests[0]
        XCTAssertEqual(ChannelRegistrar.taskID, task.taskID)
        XCTAssertEqual(options, task.options)
        XCTAssertEqual(0, task.minDelay)
    }

    func testCreateChannel() throws {
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        self.delegate.channelPayload = payload

        let expectation = XCTestExpectation(description: "callback called")
        self.client.createCallback = { channelPayload, callback in
            XCTAssertEqual(channelPayload, payload)
            callback(
                ChannelCreateResponse(
                    status: 201,
                    channelID: "some-channel-id"
                ),
                nil
            )
            expectation.fulfill()
        }

        let task = self.taskManager.launchSync(taskID: ChannelRegistrar.taskID)
        XCTAssertTrue(task.completed)
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
        XCTAssertEqual(
            "some-channel-id",
            self.delegate.channelCreatedResponse!.0
        )
        XCTAssertFalse(self.delegate.channelCreatedResponse!.1)
    }

    func testCreateChannelExisting() throws {
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        self.delegate.channelPayload = payload

        let expectation = XCTestExpectation(description: "callback called")
        self.client.createCallback = { channelPayload, callback in
            XCTAssertEqual(channelPayload, payload)
            callback(
                ChannelCreateResponse(
                    status: 200,
                    channelID: "some-channel-id"
                ),
                nil
            )
            expectation.fulfill()
        }

        let task = self.taskManager.launchSync(taskID: ChannelRegistrar.taskID)
        XCTAssertTrue(task.completed)
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
        XCTAssertEqual(
            "some-channel-id",
            self.delegate.channelCreatedResponse!.0
        )
        XCTAssertTrue(self.delegate.channelCreatedResponse!.1)
    }

    func testCreateChannelFailed() {
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        let error = AirshipErrors.error("Some error")

        self.delegate.channelPayload = payload

        let expectation = XCTestExpectation(description: "callback called")
        self.client.createCallback = { channelPayload, callback in
            XCTAssertEqual(channelPayload, payload)
            callback(nil, error)
            expectation.fulfill()
        }

        let task = self.taskManager.launchSync(taskID: ChannelRegistrar.taskID)
        XCTAssertTrue(task.failed)
        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(self.delegate.didRegistrationSucceed!)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    func testUpdateChannel() {
        let someChannelID = UUID().uuidString
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        // Create the channel
        self.delegate.channelPayload = payload
        createChannel(channelID: someChannelID)

        // Modify the payload so the update happens
        payload.channel.deviceModel = UUID().uuidString

        let expectation = XCTestExpectation(description: "callback called")
        self.client.updateCallback = { channelID, channelPayload, callback in
            XCTAssertEqual(someChannelID, channelID)
            XCTAssertEqual(channelPayload, payload)
            callback(HTTPResponse(status: 200), nil)
            expectation.fulfill()
        }

        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": false]
        )
        let task = self.taskManager.launchSync(
            taskID: ChannelRegistrar.taskID,
            options: options
        )
        XCTAssertTrue(task.completed)
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    func testSkipUpdateChannelUpToDate() {
        let someChannelID = UUID().uuidString
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        // Create the channel
        self.delegate.channelPayload = payload
        createChannel(channelID: someChannelID)

        // Try to update
        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": false]
        )
        let task = self.taskManager.launchSync(
            taskID: ChannelRegistrar.taskID,
            options: options
        )
        XCTAssertTrue(task.completed)

        XCTAssertNil(self.delegate.didRegistrationSucceed)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    func testUpdateForcefully() {
        let someChannelID = UUID().uuidString
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        // Create the channel
        self.delegate.channelPayload = payload
        createChannel(channelID: someChannelID)

        // Do not update the payload, should still update

        let expectation = XCTestExpectation(description: "callback called")
        self.client.updateCallback = { channelID, channelPayload, callback in
            XCTAssertEqual(someChannelID, channelID)
            // will use the minimized payload
            XCTAssertEqual(
                channelPayload,
                payload.minimizePayload(previous: payload)
            )
            callback(HTTPResponse(status: 200), nil)
            expectation.fulfill()
        }

        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": true]
        )
        let task = self.taskManager.launchSync(
            taskID: ChannelRegistrar.taskID,
            options: options
        )
        XCTAssertTrue(task.completed)
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    func testFullUpdate() {
        let someChannelID = UUID().uuidString
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        // Create the channel
        self.delegate.channelPayload = payload
        createChannel(channelID: someChannelID)

        self.channelRegistrar.performFullRegistration()
        XCTAssertEqual(1, self.taskManager.enqueuedRequestsCount)

        let expectation = XCTestExpectation(description: "callback called")
        self.client.updateCallback = { channelID, channelPayload, callback in
            XCTAssertEqual(someChannelID, channelID)
            // will use the full
            XCTAssertEqual(channelPayload, payload)
            callback(HTTPResponse(status: 200), nil)
            expectation.fulfill()
        }

        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": true]
        )
        let task = self.taskManager.launchSync(
            taskID: ChannelRegistrar.taskID,
            options: options
        )
        XCTAssertTrue(task.completed)
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    func testUpdateMinimizedPayload() throws {
        let someChannelID = UUID().uuidString

        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        payload.channel.appVersion = "1.0.0"

        let updatePayload = ChannelRegistrationPayload()
        updatePayload.channel.deviceModel = payload.channel.deviceModel
        payload.channel.appVersion = "2.0.0"

        let minimized = updatePayload.minimizePayload(previous: payload)
        XCTAssertNotEqual(minimized, updatePayload)

        // Create the channel with first payload
        self.delegate.channelPayload = payload
        createChannel(channelID: someChannelID)

        // Update with updated payload
        self.delegate.channelPayload = updatePayload

        let expectation = XCTestExpectation(description: "callback called")
        self.client.updateCallback = { channelID, channelPayload, callback in
            XCTAssertEqual(someChannelID, channelID)

            // Verify it uses minimized payload
            XCTAssertEqual(channelPayload, minimized)

            callback(HTTPResponse(status: 200), nil)
            expectation.fulfill()
        }

        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": false]
        )
        let task = self.taskManager.launchSync(
            taskID: ChannelRegistrar.taskID,
            options: options
        )
        XCTAssertTrue(task.completed)
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    func testUpdateAfter24Hours() {
        self.date.dateOverride = Date()

        let someChannelID = UUID().uuidString
        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        // Create the channel
        self.delegate.channelPayload = payload
        createChannel(channelID: someChannelID)

        // Try to update
        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": false]
        )
        XCTAssertTrue(
            self.taskManager
                .launchSync(
                    taskID: ChannelRegistrar.taskID,
                    options: options
                )
                .completed
        )
        XCTAssertNil(self.delegate.didRegistrationSucceed)

        // Forward to almost 1 second before 24 hours
        self.date.offset = 24 * 60 * 60 - 1

        // Should still not update
        XCTAssertTrue(
            self.taskManager
                .launchSync(
                    taskID: ChannelRegistrar.taskID,
                    options: options
                )
                .completed
        )
        XCTAssertNil(self.delegate.didRegistrationSucceed)

        // 24 hours
        self.date.offset += 1

        // Expect an update
        let expectation = XCTestExpectation(description: "callback called")
        self.client.updateCallback = { channelID, channelPayload, callback in
            XCTAssertEqual(someChannelID, channelID)
            XCTAssertEqual(
                channelPayload,
                payload.minimizePayload(previous: payload)
            )
            callback(HTTPResponse(status: 200), nil)
            expectation.fulfill()
        }

        XCTAssertTrue(
            self.taskManager
                .launchSync(
                    taskID: ChannelRegistrar.taskID,
                    options: options
                )
                .completed
        )
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.delegate.didRegistrationSucceed!)
    }

    func testUpdateFailed() {
        let someChannelID = UUID().uuidString

        let payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.delegate.channelPayload = payload

        // Create a channel
        createChannel(channelID: someChannelID)

        // Expect an update
        let expectation = XCTestExpectation(description: "callback called")
        self.client.updateCallback = { channelID, channelPayload, callback in
            XCTAssertEqual(someChannelID, channelID)
            XCTAssertEqual(
                channelPayload,
                payload.minimizePayload(previous: payload)
            )
            callback(nil, AirshipErrors.error("failed!"))
            expectation.fulfill()
        }

        let options = TaskRequestOptions(
            conflictPolicy: .replace,
            requiresNetwork: true,
            extras: ["forcefully": true]
        )
        XCTAssertTrue(
            self.taskManager
                .launchSync(
                    taskID: ChannelRegistrar.taskID,
                    options: options
                )
                .failed
        )
        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(self.delegate.didRegistrationSucceed!)
        XCTAssertNil(self.delegate.channelCreatedResponse)
    }

    private func createChannel(channelID: String) {
        self.client.createCallback = { channelPayload, callback in
            callback(
                ChannelCreateResponse(status: 200, channelID: channelID),
                nil
            )
        }
        let task = self.taskManager.launchSync(taskID: ChannelRegistrar.taskID)
        XCTAssertTrue(task.completed)

        // Clear state
        self.client.createCallback = nil
        self.delegate.didRegistrationSucceed = nil
        self.delegate.channelCreatedResponse = nil
    }
}

internal class TestChannelRegistrarDelegate: ChannelRegistrarDelegate {

    var channelCreatedResponse: (String, Bool)?
    var didRegistrationSucceed: Bool?
    var channelPayload: ChannelRegistrationPayload?

    func channelCreated(channelID: String, existing: Bool) {
        self.channelCreatedResponse = (channelID, existing)
    }

    func createChannelPayload(
        completionHandler: @escaping (ChannelRegistrationPayload) -> Void
    ) {
        completionHandler(self.channelPayload!)
    }

    func registrationFailed() {
        self.didRegistrationSucceed = false
    }

    func registrationSucceeded() {
        self.didRegistrationSucceed = true
    }
}

internal class TestChannelRegistrationClient: ChannelAPIClientProtocol {

    var createCallback:
        (
            (
                ChannelRegistrationPayload,
                ((ChannelCreateResponse?, Error?) -> Void)
            )
                -> Void
        )?
    var updateCallback:
        (
            (
                String, ChannelRegistrationPayload,
                ((HTTPResponse?, Error?) -> Void)
            ) ->
                Void
        )?
    var defaultCallback: ((String) -> Void)?

    @discardableResult
    func createChannel(
        withPayload payload: ChannelRegistrationPayload,
        completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = createCallback {
            callback(payload, completionHandler)
        } else {
            defaultCallback?("createChannel")
        }

        return Disposable()
    }

    @discardableResult
    func updateChannel(
        withID channelID: String,
        withPayload payload: ChannelRegistrationPayload,
        completionHandler: @escaping (HTTPResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = updateCallback {
            callback(channelID, payload, completionHandler)
        } else {
            defaultCallback?("updateChannel")
        }

        return Disposable()
    }

}
