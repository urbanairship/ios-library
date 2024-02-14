/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class EventManagerTest: XCTestCase {

    private let eventAPIClient = TestEventAPIClient()
    private let eventScheduler = TestEventUploadScheduler()
    private let channel = TestChannel()

    private let eventStore = EventStore(
        appKey: UUID().uuidString,
        inMemory: true
    )
    private let dataStore = PreferenceDataStore(
        appKey: UUID().uuidString
    )
    private var eventManager: EventManager!

    override func setUpWithError() throws {
        self.eventManager = EventManager(
            dataStore: dataStore,
            channel: channel,
            eventStore: eventStore,
            eventAPIClient: eventAPIClient,
            eventScheduler: eventScheduler
        )
        channel.identifier = "some channel"
    }

    func testAddEvent() async throws {
        let eventData = AirshipEventData.makeTestData()

        try await eventManager.addEvent(eventData)
        let events = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        XCTAssertEqual([eventData], events)
    }

    func testScheduleUpload() async throws {
        self.eventManager.uploadsEnabled = true
        await self.eventManager.scheduleUpload(eventPriority: .high)
        XCTAssertEqual(
            60, // min batch interval
            self.eventScheduler.lastMinBatchInterval
        )

        XCTAssertEqual(
            AirshipEventPriority.high,
            self.eventScheduler.lastScheduleUploadPriority
        )
    }

    func testScheduleUploadDisabled() async throws {
        self.eventManager.uploadsEnabled = false
        await self.eventManager.scheduleUpload(eventPriority: .high)
        XCTAssertNil(self.eventScheduler.lastMinBatchInterval)
        XCTAssertNil(self.eventScheduler.lastScheduleUploadPriority)
    }

    func testDeleteAll() async throws {
        let eventData = AirshipEventData.makeTestData()

        try await eventManager.addEvent(eventData)
        try await eventManager.deleteEvents()

        let events = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testEventUpload() async throws {
        self.eventManager.uploadsEnabled = true

        var requestCalled = false

        let events = [
            AirshipEventData.makeTestData(),
            AirshipEventData.makeTestData()
        ]

        let headers = ["some": "header"]

        await self.eventManager.addHeaderProvider {
            return headers
        }

        for event in events {
            try await self.eventStore.save(event: event)
        }

        self.eventAPIClient.requestBlock = { reqEvents, channelID, reqHeaders in
            requestCalled = true
            XCTAssertEqual(events, reqEvents)
            XCTAssertEqual(headers, reqHeaders)
            XCTAssertEqual(channelID, "some channel")

            let tuningInfo = EventUploadTuningInfo(
                maxTotalStoreSizeKB: nil,
                maxBatchSizeKB: nil,
                minBatchInterval: nil
            )

            return AirshipHTTPResponse(
                result: tuningInfo,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertTrue(requestCalled)

        let storedEvents = try await self.eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        XCTAssertTrue(storedEvents.isEmpty)
    }

    func testEventUploadFailed() async throws {
        self.eventManager.uploadsEnabled = true

        try await self.eventStore.save(
            event: AirshipEventData.makeTestData()
        )

        self.eventAPIClient.requestBlock = { reqEvents, _, reqHeaders in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        XCTAssertEqual(AirshipWorkResult.failure, result)

        let storedEvents = try await self.eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        XCTAssertEqual(1, storedEvents.count)
    }

    func testEventUploadNoTuningInfo() async throws {
        self.eventManager.uploadsEnabled = true

        try await self.eventStore.save(
            event: AirshipEventData.makeTestData()
        )

        self.eventAPIClient.requestBlock = { reqEvents, _, reqHeaders in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        XCTAssertEqual(AirshipWorkResult.success, result)
    }

    func testEventUploadHeaders() async throws {
        self.eventManager.uploadsEnabled = true
        var requestCalled = false

        await self.eventManager.addHeaderProvider {
            ["foo": "1", "baz": "1"]
        }

        await self.eventManager.addHeaderProvider {
            ["foo": "2", "bar": "2"]
        }

        try await self.eventStore.save(
            event: AirshipEventData.makeTestData()
        )

        self.eventAPIClient.requestBlock = { reqEvents, _, reqHeaders in
            let expectedHeaders = [
                "foo": "2",
                "bar": "2",
                "baz": "1"
            ]
            XCTAssertEqual(expectedHeaders, reqHeaders)
            requestCalled = true
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertTrue(requestCalled)
    }

    func testEventUploadDisabled() async throws {
        self.eventManager.uploadsEnabled = false

        try await self.eventStore.save(
            event: AirshipEventData.makeTestData()
        )

        self.eventAPIClient.requestBlock = { reqEvents, _, reqHeaders in
            XCTFail("Should not be called")

            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        XCTAssertEqual(AirshipWorkResult.success, result)
    }

    func testEventUploadUpdatedMinInterval() async throws {
        self.eventManager.uploadsEnabled = true

        try await self.eventStore.save(
            event: AirshipEventData.makeTestData()
        )

        self.eventAPIClient.requestBlock = { reqEvents, _, reqHeaders in
            let tuningInfo = EventUploadTuningInfo(
                maxTotalStoreSizeKB: nil,
                maxBatchSizeKB: nil,
                minBatchInterval: 100
            )

            return AirshipHTTPResponse(
                result: tuningInfo,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        XCTAssertEqual(AirshipWorkResult.success, result)

        await self.eventManager.scheduleUpload(eventPriority: .normal)
        XCTAssertEqual(
            100, // min batch interval
            self.eventScheduler.lastMinBatchInterval
        )
    }
}

final class TestEventAPIClient: EventAPIClientProtocol, @unchecked Sendable {
    var requestBlock: (([AirshipEventData], String, [String: String]) async throws -> AirshipHTTPResponse<EventUploadTuningInfo>)?

    func uploadEvents(_ events: [AirshipEventData], channelID: String, headers: [String : String]) async throws -> AirshipHTTPResponse<EventUploadTuningInfo> {

        guard let block = requestBlock else {
            throw AirshipErrors.error("Request block not set")
        }

        return try await block(events, channelID, headers)
    }
}

final class TestEventUploadScheduler: EventUploadSchedulerProtocol, @unchecked Sendable {
    var workBlock: (() async throws -> AirshipWorkResult)?

    var lastScheduleUploadPriority: AirshipEventPriority?
    var lastMinBatchInterval: TimeInterval?

    func scheduleUpload(
        eventPriority: AirshipEventPriority,
        minBatchInterval: TimeInterval
    ) async {
        self.lastMinBatchInterval  = minBatchInterval
        self.lastScheduleUploadPriority = eventPriority
    }

    func setWorkBlock(
        _ workBlock: @escaping () async throws -> AirshipCore.AirshipWorkResult
    ) async {

        self.workBlock = workBlock
    }
}

