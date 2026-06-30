/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore
import Foundation

@Suite struct EventStoreTest {

    private let eventStore = EventStore(
        appKey: UUID().uuidString,
        inMemory: true
    )

    @Test
    func testAdd() async throws {
        let events = generateEvents(count: 2)
        for event in events {
            try await self.eventStore.save(event: event)
        }

        let storedEvents = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )
        #expect(events == storedEvents)
    }

    @Test
    func testDeleteAll() async throws {
        let events = generateEvents(count: 10)
        for event in events {
            try await self.eventStore.save(event: event)
        }

        try await self.eventStore.deleteAllEvents()

        let storedEvents = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )


        #expect(storedEvents.isEmpty)
    }

    @Test
    func testDeleteEventIDs() async throws {
        let events = generateEvents(count: 10)
        for event in events {
            try await self.eventStore.save(event: event)
        }

        try await self.eventStore.deleteEvents(
            eventIDs: [
                events[0].id,
                events[1].id,
                events[2].id
            ]
        )

        let storedEvents = try await eventStore.fetchEvents(
            maxBatchSizeKB: 1000
        )

        let expectedEvents = Array(events[3...9])
        #expect(expectedEvents == storedEvents)
    }

    func generateEvents(
        count: Int
    ) -> [AirshipEventData] {
        var events: [AirshipEventData] = []

        for _ in 1...count {
            events.append(
                AirshipEventData.makeTestData()
            )
        }

        return events
    }
}
