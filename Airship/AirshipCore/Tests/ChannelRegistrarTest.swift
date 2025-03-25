/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore
class ChannelRegistrarTest: XCTestCase {

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let client = TestChannelRegistrationClient()
    private let date = UATestDate()
    private let workManager = TestWorkManager()
    private let appStateTracker = TestAppStateTracker()
    private var subscriptions: Set<AnyCancellable> = Set()
    private var payloadProvider = ChannelRegistrationPayloadProvider()
    private let workID = "UAChannelRegistrar.registration"

    private var channelRegistrar: ChannelRegistrar!
    private var channelCreateMethod: ChannelGenerationMethod = .automatic

    override func tearDown() async throws {
        self.subscriptions.removeAll()
    }

    actor ChannelRegistrationPayloadProvider {
        private var payload: ChannelRegistrationPayload

        init(deviceModel: String? = nil, appVersion: String? = nil) {
            var payload = ChannelRegistrationPayload()
            payload.channel.deviceModel = deviceModel ?? UUID().uuidString
            payload.channel.appVersion = appVersion ?? "test"

            self.payload = payload
        }

        func updatePayload(update: @Sendable @escaping(inout ChannelRegistrationPayload) -> Void ) {
            update(&payload)
        }

        func getPayload() -> ChannelRegistrationPayload {
            payload
        }
    }

    func testRegister() async throws {
        await makeRegistrar()
        XCTAssertEqual(0, self.workManager.workRequests.count)

        self.channelRegistrar.register(forcefully: false)

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let extras = ["forcefully": "false"]

        let request = self.workManager.workRequests[0]
        XCTAssertEqual(workID, request.workID)
        XCTAssertEqual(.keepIfNotStarted, request.conflictPolicy)
        XCTAssertEqual(extras, request.extras)
        XCTAssertEqual(0, request.initialDelay)
    }

    func testRegisterForcefully() async throws {
        await makeRegistrar()
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
        await makeRegistrar()

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
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

        await self.fulfillment(of: [channelUpdated], timeout: 10.0)
    }

    func testCreateChannelRestores() async throws {
        let restoredUUID = UUID().uuidString
        self.channelCreateMethod = .restore(channelID: restoredUUID)
        await makeRegistrar()
        
        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        self.client.createCallback =  { channelPayload in
            XCTFail()
            throw AirshipErrors.error("")
        }

        let channelUpdated = self.expectation(description: "channel updated")
        var updateCounter = 0
        self.channelRegistrar.updatesPublisher.sink { update in
            switch update {
            case .created(let channelID, let isExisting):
                XCTAssertEqual(restoredUUID, channelID)
                XCTAssertTrue(isExisting)
            case .updated(let channelID):
                XCTAssertEqual(restoredUUID, channelID)
            }
            updateCounter += 1
            if updateCounter > 1 {
                channelUpdated.fulfill()
            }
        }.store(in: &self.subscriptions)
        
        self.client.updateCallback = { channelID, channelPayload in
            XCTAssertEqual(restoredUUID, channelID)
            XCTAssertNil(channelPayload.channel.deviceModel) // minimized
            
            return AirshipHTTPResponse(
                result: ChannelAPIResponse(
                    channelID: restoredUUID,
                    location: try self.client.makeChannelLocation(
                        channelID: "some-channel-id"
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

        await self.fulfillment(of: [channelUpdated], timeout: 10.0)
    }

    func testRestoreFallBackToCreateOnInvalidID() async throws {
        self.channelCreateMethod = .restore(channelID: "invalid-uuid")
        await makeRegistrar()

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        let create = expectation(description: "create block called")
        self.client.createCallback =  { channelPayload in
            XCTAssertEqual(channelPayload, payload)
            create.fulfill()
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

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)

        await self.fulfillment(of: [create], timeout: 10.0)
    }

    func testCreateChannelExisting() async throws {
        await makeRegistrar()

        let payload = await payloadProvider.getPayload()
        
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

        await self.fulfillment(of: [channelUpdated], timeout: 10.0)
    }

    func testCreateChannelError() async throws {
        await makeRegistrar()
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
        await makeRegistrar()
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:])
        }


        let payload = await payloadProvider.getPayload()
        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.failure, result)
    }

    func testCreateChannelClientError() async throws {
        await makeRegistrar()
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let payload = await payloadProvider.getPayload()

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.success, result)
    }
    
    func testUpdateNotConfigured() async {
        await makeRegistrar()
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
        await makeRegistrar()
        self.client.createCallback =  { channelPayload in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 429,
                headers: [:])
        }

        let payload = await payloadProvider.getPayload()
        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(workID: workID)
        )

        XCTAssertEqual(.failure, result)
    }

    func testUpdateChannel() async throws {
        await makeRegistrar()
        let someChannelID = UUID().uuidString

        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        let payload = await payloadProvider.getPayload()


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
        self.channelRegistrar.updatesPublisher.dropFirst().sink { update in
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
        await self.fulfillment(of: [channelUpdated], timeout: 10)
    }

    func testUpdateChannelError() async throws {
        await makeRegistrar()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
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
        await makeRegistrar()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
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
        await makeRegistrar()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
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
    

    @MainActor
    func testUpdateChannel429Error() async throws {
        await makeRegistrar()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        await payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
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
        await makeRegistrar()

        let payload = await payloadProvider.getPayload()

        await MainActor.run {
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return payload
            }
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
        await makeRegistrar()
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
        self.channelRegistrar.updatesPublisher.dropFirst().sink { update in
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
        await self.fulfillment(of: [channelUpdated], timeout: 10)
    }

    func testUpdateLocationChanged() async throws {
        await makeRegistrar()
        let someChannelID = UUID().uuidString

        let payload = await payloadProvider.getPayload()

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
        self.channelRegistrar.updatesPublisher.dropFirst().sink { update in
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
        await self.fulfillment(of: [channelUpdated], timeout: 10)
    }

    func testUpdateMinPayload() async throws {
        await makeRegistrar()
        let someChannelID = UUID().uuidString

        let firstPayload = await self.payloadProvider.getPayload()

        try await createChannel(channelID: someChannelID)

        await self.payloadProvider.updatePayload { payload in
            payload.channel.deviceModel = UUID().uuidString
        }

        let secondPayload = await payloadProvider.getPayload()

        self.client.updateCallback = { channelID, channelPayload in
            XCTAssertEqual(
                secondPayload.minimizePayload(
                    previous: firstPayload
                ),
                channelPayload
            )
            XCTAssertNotEqual(secondPayload, channelPayload)
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
        self.channelRegistrar.updatesPublisher.dropFirst().sink { update in
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
        await self.fulfillment(of: [channelUpdated], timeout: 10)
    }

    @MainActor
    func testUpdateAfter24Hours() async throws {
        await makeRegistrar()
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
    
    @MainActor
    public func testFullPayloadUploadAfter24Hours() async throws {
        await makeRegistrar()
        self.appStateTracker.currentState = .active
        self.date.dateOverride = Date()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        let payload = await payloadProvider.getPayload()

        var updatePayload: ChannelRegistrationPayload? = nil
        self.client.updateCallback = { channelID, channelPayload in
            updatePayload = channelPayload
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
        
        XCTAssertNil(updatePayload)

        self.date.offset = 24 * 60 * 60 - 1

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )

        XCTAssertNil(updatePayload)

        // 24 hours
        self.date.offset += 2

        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        
        XCTAssertEqual(payload, updatePayload)
    }

    fileprivate struct LastRegistrationInfo: Codable {
        var date: Date
        var payload: ChannelRegistrationPayload
        var lastFullPayloadSent: Date?
        var location: URL
    }

    @MainActor
    public func testEmptyLastFullRegistration() async throws {
        await makeRegistrar()
        self.appStateTracker.currentState = .active
        self.date.dateOverride = Date()
        let someChannelID = UUID().uuidString
        try await createChannel(channelID: someChannelID)

        var registrationInfo: LastRegistrationInfo = self.dataStore.safeCodable(forKey: "ChannelRegistrar.lastRegistrationInfo")!
        registrationInfo.lastFullPayloadSent = nil
        self.dataStore.setSafeCodable(registrationInfo, forKey: "ChannelRegistrar.lastRegistrationInfo")

        let payload = await payloadProvider.getPayload()

        var updatePayload: ChannelRegistrationPayload? = nil
        self.client.updateCallback = { channelID, channelPayload in
            updatePayload = channelPayload
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

        XCTAssertEqual(payload, updatePayload)

       updatePayload = nil
        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: workID
            )
        )
        
        // No update
        XCTAssertNil(updatePayload)
    }


    private func createChannel(channelID: String) async throws {
        // Set a payload since the create flow now requires one
        let payload = await payloadProvider.getPayload()

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
    
    private func makeRegistrar() async {
        await MainActor.run {
            self.channelRegistrar = ChannelRegistrar(
                dataStore: self.dataStore,
                channelAPIClient: self.client,
                date: self.date,
                workManager:  self.workManager,
                appStateTracker: self.appStateTracker,
                channelCreateMethod: { return self.channelCreateMethod },
                privacyManager: TestPrivacyManager(dataStore: self.dataStore,
                                                   config: RuntimeConfig.testConfig(),
                                                   defaultEnabledFeatures: AirshipFeature.all)
            )

            let payloadProvider = self.payloadProvider
            self.channelRegistrar.payloadCreateBlock = { await payloadProvider.getPayload() }
        }

    }
}

internal class TestChannelRegistrationClient: ChannelAPIClientProtocol, @unchecked Sendable {
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
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {
        return try await updateCallback!(channelID, payload)
    }
}
