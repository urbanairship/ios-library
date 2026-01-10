// Copyright Urban Airship and Contributors


import Foundation
import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct AutomationEventsHistoryTest {
    let clock = UATestDate(dateOverride: Date())
    
    private func makeSubject() -> DefaultAutomationEventsHistory {
        return DefaultAutomationEventsHistory(
            clock: clock
        )
    }

    @Test
    func testAddAndRetrieveEvent() async {
        let subject = makeSubject()
        await subject.add(.event(type: .foreground))

        let events = await subject.events
        #expect(events.count == 1)
        #expect(events.first == AutomationEvent.event(type: .foreground, data: nil, value: 1.0))
    }

    @Test
    func testPrunesEventsOlderThanMaxDuration() async {
        let subject = makeSubject()

        // Add an event at the current time
        await subject.add(.event(type: .foreground))

        // Advance time beyond the max duration (30 seconds in implementation)
        clock.advance(by: 31)

        let events = await subject.events
        #expect(events.count == 0, "Events older than maxDuration should be pruned")
    }

    @Test
    func testKeepsOnlyMostRecentMaxEvents() async {
        let subject = makeSubject()
        
        // Add 110 events; DefaultAutomationEventsHistory keeps last 100
        let total = 110
        for i in 0..<total {
            await subject.add(.event(type: .customEventValue, data: nil, value: Double(i)))
        }

        let events = await subject.events
        #expect(events.count == 100, "Expected to keep only the last 100 events")

        // The first kept event should correspond to index 10 (110 - 100)
        let firstEventValue: Double? = if case .event(_, _, let value) = events.first {
            value
        } else {
            nil
        }
        #expect(firstEventValue == 10)
        
        let lastEventValue: Double? = if case .event(_, _, let value) = events.last {
            value
        } else {
            nil
        }
        
        #expect(lastEventValue == 109)
    }
}
