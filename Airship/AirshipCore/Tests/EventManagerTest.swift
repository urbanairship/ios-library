/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable
@_spi(AirshipInternal) import AirshipCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
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

    /// Runs the upload work block once the manager has registered it.
    ///
    /// The manager registers its block from an unawaited `Task` in `init`, so this waits for it
    /// rather than for a fixed time, which a loaded CI machine can outlast.
    private func runWorkBlock() async throws -> AirshipWorkResult? {
        return try await eventScheduler.registeredWorkBlock()()
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

        let result = try await self.runWorkBlock()
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

        let result = try await self.runWorkBlock()
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

        let result = try await self.runWorkBlock()
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

        let result = try await self.runWorkBlock()
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

        let result = try await self.runWorkBlock()
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

        let result = try await self.runWorkBlock()
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
    typealias WorkBlock = () async throws -> AirshipWorkResult

    /// Carries the block across the continuation; the lock guards every access to it.
    private struct Registered: @unchecked Sendable {
        let block: WorkBlock
    }

    private let lock = NSLock()
    private var _workBlock: WorkBlock?
    private var waiters: [CheckedContinuation<Registered, Never>] = []

    var workBlock: WorkBlock? {
        lock.withLock { _workBlock }
    }

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
        let waiting = lock.withLock {
            _workBlock = workBlock
            defer { waiters.removeAll() }
            return waiters
        }
        waiting.forEach { $0.resume(returning: Registered(block: workBlock)) }
    }

    /// Returns the work block once it's set, however long that takes.
    func registeredWorkBlock() async -> WorkBlock {
        let registered = await withCheckedContinuation { continuation in
            let ready: Registered? = lock.withLock {
                if let block = _workBlock { return Registered(block: block) }
                waiters.append(continuation)
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
        return registered.block
    }
}
