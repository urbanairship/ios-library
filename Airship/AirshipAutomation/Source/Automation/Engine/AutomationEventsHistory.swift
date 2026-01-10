/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationEventsHistory: Sendable {
    var events: [AutomationEvent] { get async }

    func add(_ event: AutomationEvent) async
}

final actor DefaultAutomationEventsHistory: AutomationEventsHistory {
    private static let maxEvents: Int = 100
    private static let maxDuration: TimeInterval = 30 // seconds
    
    private let clock: any AirshipDateProtocol
    private var eventsHistory: [Entry] = []
    
    init(clock: any AirshipDateProtocol = AirshipDate()) {
        self.clock = clock
    }
    
    private struct Entry {
        let event: AutomationEvent
        let timestamp: Date
    }
    
    var events: [AutomationEvent] {
        return prunedEvents().map(\.event)
    }
    
    func add(_ event: AutomationEvent) {
        var filtered = prunedEvents()
        filtered.append(Entry(event: event, timestamp: clock.now))
        eventsHistory = filtered
    }
    
    private func prunedEvents() -> [Entry] {
        return eventsHistory
            .suffix(Self.maxEvents)
            .filter { self.clock.now.timeIntervalSince($0.timestamp) < Self.maxDuration }
    }
}
