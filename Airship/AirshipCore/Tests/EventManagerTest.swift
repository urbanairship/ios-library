/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable
import AirshipCore

@MainActor
@Suite
struct EventManagerTest {

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

    init() {
        self.eventManager = EventManager(
            dataStore: dataStore,
            channel: channel,
            eventStore: eventStore,
            eventAPIClient: eventAPIClient,
            eventScheduler: eventScheduler
        )
        channel.identifier = "some channel"
    }

    @Test
    func testAddEvent() async throws {
        let eventData = AirshipEventData.makeTestData()

        try await eventManager.addEvent(eventData)
        let events = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        #expect([eventData] == events)
    }

    @Test
    func testScheduleUpload() async throws {
        self.eventManager.uploadsEnabled = true
        await self.eventManager.scheduleUpload(eventPriority: .high)
        #expect(
            60 == // min batch interval
            self.eventScheduler.lastMinBatchInterval
        )

        #expect(
            AirshipEventPriority.high ==
            self.eventScheduler.lastScheduleUploadPriority
        )
    }

    @Test
    func testScheduleUploadDisabled() async throws {
        self.eventManager.uploadsEnabled = false
        await self.eventManager.scheduleUpload(eventPriority: .high)
        #expect(self.eventScheduler.lastMinBatchInterval == nil)
        #expect(self.eventScheduler.lastScheduleUploadPriority == nil)
    }

    @Test
    func testDeleteAll() async throws {
        let eventData = AirshipEventData.makeTestData()

        try await eventManager.addEvent(eventData)
        try await eventManager.deleteEvents()

        let events = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        #expect(events.isEmpty)
    }

    @Test
    func testEventUpload() async throws {
        self.eventManager.uploadsEnabled = true

        var requestCalled = false

        let events = [
            AirshipEventData.makeTestData(),
            AirshipEventData.makeTestData()
        ]

        let headers = ["some": "header"]

        self.eventManager.addHeaderProvider {
            return headers
        }

        for event in events {
            try await self.eventStore.save(event: event)
        }

        self.eventAPIClient.requestBlock = { reqEvents, channelID, reqHeaders in
            requestCalled = true
            #expect(events == reqEvents)
            #expect(headers == reqHeaders)
            #expect(channelID == "some channel")

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
        #expect(AirshipWorkResult.success == result)
        #expect(requestCalled)

        let storedEvents = try await self.eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        #expect(storedEvents.isEmpty)
    }

    @Test
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
        #expect(AirshipWorkResult.failure == result)

        let storedEvents = try await self.eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        #expect(1 == storedEvents.count)
    }

    @Test
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
        #expect(AirshipWorkResult.success == result)
    }

    @Test
    func testEventUploadHeaders() async throws {
        self.eventManager.uploadsEnabled = true
        var requestCalled = false

        self.eventManager.addHeaderProvider {
            ["foo": "1", "baz": "1"]
        }

        self.eventManager.addHeaderProvider {
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
            #expect(expectedHeaders == reqHeaders)
            requestCalled = true
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        #expect(AirshipWorkResult.success == result)
        #expect(requestCalled)
    }

    @Test
    func testEventUploadDisabled() async throws {
        self.eventManager.uploadsEnabled = false

        try await self.eventStore.save(
            event: AirshipEventData.makeTestData()
        )

        self.eventAPIClient.requestBlock = { reqEvents, _, reqHeaders in
            Issue.record("Should not be called")

            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.eventScheduler.workBlock?()
        #expect(AirshipWorkResult.success == result)
    }

    @Test
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
        #expect(AirshipWorkResult.success == result)

        await self.eventManager.scheduleUpload(eventPriority: .normal)
        #expect(
            100 == // min batch interval
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
