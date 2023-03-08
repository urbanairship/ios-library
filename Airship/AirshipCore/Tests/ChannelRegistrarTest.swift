/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore
class ChannelRegistrarTest: XCTestCase {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let client = TestChannelRegistrationClient()
    private let date = UATestDate()
    private let workManager = TestWorkManager()
    private let dispatcher = TestDispatcher()
    private let appStateTracker = TestAppStateTracker()
    private var subscriptions: Set<AnyCancellable> = Set()

    private let workID = "UAChannelRegistrar.registration"

    private var channelRegistrar: ChannelRegistrar!

    override func setUpWithError() throws {
        self.channelRegistrar = ChannelRegistrar(
            dataStore: self.dataStore,
            channelAPIClient: self.client,
            date: self.date,
            workManager:  self.workManager,
            appStateTracker: self.appStateTracker
        )
    }

    override func tearDown() async throws {
        self.subscriptions.removeAll()
    }

    func testRegister() throws {
        XCTAssertEqual(0, self.workManager.workRequests.count)

        self.channelRegistrar.register(forcefully: false)

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let extras = ["forcefully": "false"]

        let request = self.workManager.workRequests[0]
        XCTAssertEqual(workID, request.workID)
        XCTAssertEqual(.keep, request.conflictPolicy)
        XCTAssertEqual(extras, request.extras)
        XCTAssertEqual(0, request.initialDelay)
    }

    func testRegisterForcefully() throws {
        XCTAssertEqual(0, self.workManager.workRequests.count)

        self.channelRegistrar.register(forcefully: true)

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let extras = ["forcefully": "true"]

        let request = self.workManager.workRequests[0]
        XCTAssertEqual(workID, request.workID)
        XCTAssertEqual(.replace, request.conflictPolicy)
        XCTAssertEqual(extras, request.extras )
        XCTAssertEqual(0, request.initialDelay)
    }

    func testCreateChannel() async throws {
        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.createCallback =  { channelPayload in
            XCTAssertEqual(channelPayload, payload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: "some-channel-id",
                    location: try self.client.makeChannelLocation(
                        channelID: "some-channel-id"
                    )
                ),
                statusCode: 201,
                headers: [:])
        }

        let channelUpdated = self.expectation(description: "channel updated")
        self.channelRegistrar.updatesPublisher.sink { update in
            guard case let .created(channelID, isExisting) = update else {
                XCTFail("Unexpected update")
                return
            }
            XCTAssertEqual("some-channel-id", channelID)
            XCTAssertFalse(isExisting)
            channelUpdated.fulfill()
        }.store(in: &self.subscriptions)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)

        await self.waitForExpectations(timeout: 10.0)
    }

    func testCreateChannelExisting() async throws {
        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.createCallback =  { channelPayload in
            XCTAssertEqual(channelPayload, payload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: "some-channel-id",
                    location: try self.client.makeChannelLocation(
                        channelID: "some-channel-id"
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let channelUpdated = self.expectation(description: "channel updated")
        self.channelRegistrar.updatesPublisher.sink { update in
            guard case let .created(channelID, isExisting) = update else {
                XCTFail("Unexpected update")
                return
            }
            XCTAssertEqual("some-channel-id", channelID)
            XCTAssertTrue(isExisting)
            channelUpdated.fulfill()
        }.store(in: &self.subscriptions)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)

        await self.waitForExpectations(timeout: 10.0)
    }

    func testCreateChannelError() async throws {
        self.client.createCallback =  { channelPayload in
            throw AirshipErrors.error("Some error")
        }

        do {
            _ = try await self.workManager.launchTask(
                request: AirshipWorkRequest(workID: workID)
            )
            XCTFail("Should throw")
        } catch {

        }
    }

    func testCreateChannelServerError() async throws {
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.failure, result)
    }

    func testCreateChannelClientError() async throws {
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)
    }
    
    func testUpdateNotConfigured() {
        self.client.isURLConfigured = false
        self.channelRegistrar.register(forcefully: true)
        self.channelRegistrar.register(forcefully: false)
        XCTAssertEqual(0, self.workManager.workRequests.count)

        self.client.isURLConfigured = true
        
        self.channelRegistrar.register(forcefully: true)
        self.channelRegistrar.register(forcefully: false)
        XCTAssertEqual(2, self.workManager.workRequests.count)
    }

    func testCreateChannel429Error() async throws {
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 429,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.failure, result)
    }

    func testUpdateChannel() async throws {
        let someChannelID = UUID().uuidString

        try await createChannel(channelID: someChannelID)

        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString

        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.updateCallback = { channelID, channelPayload in
            XCTAssertEqual(someChannelID, channelID)
            XCTAssertEqual(
                channelPayload.channel.deviceModel,
                payload.channel.deviceModel
            )
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: "some-channel-id"
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let channelUpdated = self.expectation(description: "channel updated")
        self.channelRegistrar.updatesPublisher.sink { update in
            guard case let .updated(channelID) = update else {
                XCTFail("Unexpected update")
                return
            }
            XCTAssertEqual(someChannelID, channelID)
            channelUpdated.fulfill()
        }.store(in: &self.subscriptions)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)
        await self.waitForExpectations(timeout: 10)
    }

    func testUpdateChannelError() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.updateCallback = { channelID, channelPayload in
            throw AirshipErrors.error("Error!")
        }

        do {
            _ = try await self.workManager.launchTask(
                request: AirshipWorkRequest(workID: workID)
            )
            XCTFail("Should throw")
        } catch {}
    }

    func testUpdateChannelServerError() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.failure, result)
    }

    func testUpdateChannelClientError() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)
    }
    

    func testUpdateChannel429Error() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 429,
                headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.failure, result)
    }

    func testSkipUpdateChannelUpToDate() async throws {
        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        let someChannelID = UUID().uuidString

        // Create the channel
        try await createChannel(channelID: someChannelID)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)
    }

    func testUpdateForcefully() async throws {
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        self.client.updateCallback = { channelID, channelPayload in
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let channelUpdated = self.expectation(description: "channel updated")
        self.channelRegistrar.updatesPublisher.sink { update in
            guard case let .updated(channelID) = update else {
                XCTFail("Unexpected update")
                return
            }
            XCTAssertEqual(someChannelID, channelID)
            channelUpdated.fulfill()
        }.store(in: &self.subscriptions)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID,
                extras: ["forcefully": "true"]
            )
        )

        XCTAssertEqual(.success, result)
        await self.waitForExpectations(timeout: 10)
    }

    func testUpdateLocationChanged() async throws {
        let someChannelID = UUID().uuidString
        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        try await createChannel(channelID: someChannelID)

        self.client.channelLocation = { _ in
            return URL(string: "some:otherlocation")!
        }

        self.client.updateCallback = { channelID, channelPayload in
            XCTAssertEqual(payload, channelPayload)
            XCTAssertNotEqual(payload.minimizePayload(previous: payload), channelPayload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let channelUpdated = self.expectation(description: "channel updated")
        self.channelRegistrar.updatesPublisher.sink { update in
            guard case let .updated(channelID) = update else {
                XCTFail("Unexpected update")
                return
            }
            XCTAssertEqual(someChannelID, channelID)
            channelUpdated.fulfill()
        }.store(in: &self.subscriptions)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        XCTAssertEqual(.success, result)
        await self.waitForExpectations(timeout: 10)
    }

    func testUpdateMinPayload() async throws {
        let someChannelID = UUID().uuidString
        var payload = ChannelRegistrationPayload()
        payload.channel.deviceModel = UUID().uuidString
        self.channelRegistrar.addChannelRegistrationExtender { _ in
            return payload
        }

        try await createChannel(channelID: someChannelID)
        let firstPayload = payload
        payload.channel.appVersion = "3.0.0"

        self.client.updateCallback = { channelID, channelPayload in
            XCTAssertEqual(
                payload.minimizePayload(
                    previous: firstPayload
                ),
                channelPayload
            )
            XCTAssertNotEqual(payload, channelPayload)
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let channelUpdated = self.expectation(description: "channel updated")
        self.channelRegistrar.updatesPublisher.sink { update in
            guard case let .updated(channelID) = update else {
                XCTFail("Unexpected update")
                return
            }
            XCTAssertEqual(someChannelID, channelID)
            channelUpdated.fulfill()
        }.store(in: &self.subscriptions)

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        XCTAssertEqual(.success, result)
        await self.waitForExpectations(timeout: 10)
    }

    func testUpdateAfter24Hours() async throws {
        self.appStateTracker.currentState = .active
        self.date.dateOverride = Date()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var updateCount = 0
        self.client.updateCallback = { channelID, channelPayload in
            updateCount += 1
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: someChannelID,
                    location: try self.client.makeChannelLocation(
                        channelID: someChannelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        XCTAssertEqual(0, updateCount)

        // Forward to almost 1 second before 24 hours
        self.date.offset = 24 * 60 * 60 - 1

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        XCTAssertEqual(0, updateCount)


        // 24 hours
        self.date.offset += 1

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        XCTAssertEqual(1, updateCount)
    }

    private func createChannel(channelID: String) async throws {
        self.client.createCallback = { _ in
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: channelID,
                    location: try self.client.makeChannelLocation(
                        channelID: channelID
                    )
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)
    }
}

internal class TestChannelRegistrationClient: ChannelAPIClientProtocol {

    var isURLConfigured: Bool = true

    var createCallback:((ChannelRegistrationPayload) async throws -> AirshipHTTPResponse<ChannelAPIResponse>)?
    var updateCallback:
    ((String, ChannelRegistrationPayload) async throws -> AirshipHTTPResponse<ChannelAPIResponse>)?

    var channelLocation: ((String) throws -> URL)?

    func makeChannelLocation(channelID: String) throws -> URL {
        guard let channelLocation = channelLocation else {
            return URL(string: "channel:\(channelID)")!
        }

        return try channelLocation(channelID)
    }

    func createChannel(
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {
        return try await createCallback!(payload)
    }

    func updateChannel(
        _ channelID: String,
        payload payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {
        return try await updateCallback!(channelID, payload)
    }

}
