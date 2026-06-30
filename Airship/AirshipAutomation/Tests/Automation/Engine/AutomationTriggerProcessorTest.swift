/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

struct AutomationTriggerProcessorTest: @unchecked Sendable {
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let store: TestTriggerStore = TestTriggerStore()
    private let processor: AutomationTriggerProcessor
    private let history: any AutomationEventsHistory

    init() {
        let history = DefaultAutomationEventsHistory(clock: date)
        self.history = history
        self.processor = AutomationTriggerProcessor(store: store, history: history, date: date)
    }
    
    @Test
    func testRestoreSchedule() async throws {
        self.store.stored = [
            TriggerData(
                scheduleID: "unused-schedule-id",
                triggerID: "unused-trigger-id",
                count: 0,
                children: [:]
            )
        ]

        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .activeSession, goal: 1))

        #expect(1 == self.store.stored.count)
        try await restoreSchedules(trigger: trigger)
        #expect(0 == self.store.stored.count)
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState(appSessionID: "foreground")))

        let result = await takeNext().first
        #expect("schedule-id" == result?.scheduleID)
        #expect(TriggerExecutionType.execution == result?.triggerExecutionType)
        #expect(TriggeringInfo(
            context: AirshipTriggerContext(
                type: "active_session",
                goal: 1.0,
                event: .null),
            date: self.date.now) == result?.triggerInfo)
    }
    
    @Test
    func testUpdateTriggersResendsStatus() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .activeSession, goal: 1))

        await self.processor.processEvent(.stateChanged(state: TriggerableState()))
        
        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState(appSessionID: "foreground")))
        

        await self.processor.updateScheduleState(scheduleID: "schedule-id", state: .idle)

        let result = await takeNext(count: 2).last
        #expect("schedule-id" == result?.scheduleID)
        #expect(TriggerExecutionType.execution == result?.triggerExecutionType)
        #expect(TriggeringInfo(
            context: AirshipTriggerContext(
                type: "active_session",
                goal: 1.0,
                event: .null),
            date: self.date.now) == result?.triggerInfo)
    }
    
    @Test
    func testCancelSchedule() async throws {
        
        try await restoreSchedules()
        
        await self.processor.processEvent(.event(type: .appInit))
        
        #expect(
            TriggerData(
                scheduleID: "schedule-id",
                triggerID: "default-trigger",
                count: 1,
                children: [:]
            ) ==
            self.store.stored.last
        )
        
        await self.processor.cancel(scheduleIDs: ["schedule-id"])
        #expect(self.store.stored.isEmpty)

        await self.processor.processEvent(.event(type: .appInit))
        
        let result = await takeNext()
        #expect(result.isEmpty)
    }
    
    @Test
    func testCancelWithGroup() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id-2", type: .appInit, goal: 2))
        let schedule = defaultSchedule(trigger: trigger, group: "test-group")
        
        try await self.processor.restoreSchedules([schedule])
        await self.processor.processEvent(.event(type: .appInit))
        
        #expect(
            TriggerData(
                scheduleID: "schedule-id",
                triggerID: "trigger-id-2",
                count: 1,
                children: [:]
            ) ==
            self.store.stored.last
        )

        await self.processor.cancel(group: "test-group")
        #expect(self.store.stored.isEmpty)

        await self.processor.processEvent(.event(type: .appInit))
        
        let result = await takeNext()
        #expect(result.isEmpty)
    }
    
    @Test
    func testProcessEventEmitsResults() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .appInit, goal: 1))

        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.event(type: .appInit))
        
        #expect(
            TriggerData(
                scheduleID: "schedule-id",
                triggerID: "trigger-id",
                count: 0,
                children: [:]
            ) ==
            self.store.stored.last
        )

        let result = await takeNext()
        #expect(!result.isEmpty)
    }
    
    @MainActor
    @Test
    func testProcessEventEmitsNothingOnPause() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .appInit, goal: 1))

        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.event(type: .appInit))
        
        var result = await takeNext()
        #expect(!result.isEmpty)
        
        await self.processor.processEvent(.event(type: .appInit))
        
        result = await takeNext()
        #expect(!result.isEmpty)
        
        self.processor.setPaused(true)
        
        await self.processor.processEvent(.event(type: .appInit))
        
        result = await takeNext()
        #expect(result.isEmpty)
    }
    
    @Test
    func testReplayEvents() async {
        let triggerOld = AutomationTrigger.event(.init(id: "trigger-id", type: .appInit, goal: 2))
        let oldSchedule = defaultSchedule(trigger: triggerOld)
        
        let event = AutomationEvent.event(type: .appInit)
        
        await self.processor.updateSchedules([oldSchedule])
        await self.processor.processEvent(event)
        await self.history.add(event)
        
        let triggerNew = AutomationTrigger.event(.init(id: "new-trigger-id", type: .appInit, goal: 1))
        let scheduleNew = AutomationScheduleData(
            schedule: AutomationSchedule(
                identifier: "new-schedule-id",
                data: .actions(.null),
                triggers: [triggerNew],
                group: nil
            ),
            scheduleState: .idle,
            lastScheduleModifiedDate: self.date.now,
            scheduleStateChangeDate: self.date.now,
            executionCount: 0,
            triggerSessionID: UUID().uuidString
        )
        
        await self.processor.updateSchedules([oldSchedule, scheduleNew])
        let results = await takeNext()
        #expect(results.count == 1)
        #expect("new-schedule-id" == results.first?.scheduleID)
        #expect(TriggerExecutionType.execution == results.first?.triggerExecutionType)
    }
    
    private func restoreSchedules(trigger: AutomationTrigger? = nil) async throws {
        let trigger = trigger ?? AutomationTrigger.event(.init(id: "default-trigger", type: .appInit, goal: 2))

        let schedule = defaultSchedule(trigger: trigger)
        
        try await self.processor.restoreSchedules([schedule])
    }
    
    private func defaultSchedule(trigger: AutomationTrigger, group: String? = nil) -> AutomationScheduleData {
        return AutomationScheduleData(
            schedule: AutomationSchedule(
                identifier: "schedule-id",
                data: .actions(.null),
                triggers: [trigger],
                group: group
            ),
            scheduleState: .idle,
            lastScheduleModifiedDate: self.date.now,
            scheduleStateChangeDate: self.date.now,
            executionCount: 0,
            triggerSessionID: UUID().uuidString
        )
    }
    
    
    
    @discardableResult
    private func takeNext(count: UInt = 1, timeout: Int = 1) async -> [TriggerResult] {
        let collectTask = Task {
            var result: [TriggerResult] = []
            var iterator = await self.processor.triggerResults.makeAsyncIterator()
            while result.count < count, !Task.isCancelled {
                if let next = await iterator.next() {
                    result.append(next)
                }
            }
            
            return result
        }
        
        let cancel = DispatchWorkItem {
            collectTask.cancel()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeout), execute: cancel)
        
        let result = await collectTask.result.get()
        cancel.cancel()
        return result
    }
}

final class TestTriggerStore: TriggerStoreProtocol, @unchecked Sendable {
    
    var stored: [TriggerData] = []

    func getTrigger(scheduleID: String, triggerID: String) async throws -> AirshipAutomation.TriggerData? {
        return stored.first(where: { $0.triggerID == triggerID && $0.scheduleID == scheduleID })
    }
    
    func upsertTriggers(_ triggers: [TriggerData]) async throws {
        let incomingIDs = triggers.map { $0.triggerID }
        stored.removeAll { incomingIDs.contains($0.triggerID) }
        stored.append(contentsOf: triggers)
    }
    
    func deleteTriggers(excludingScheduleIDs: Set<String>) async throws {
        stored.removeAll(where: { !excludingScheduleIDs.contains($0.scheduleID) })
    }
    
    func deleteTriggers(scheduleIDs: [String]) async throws {
        stored.removeAll(where: { scheduleIDs.contains($0.scheduleID) })
    }
    
    func deleteTriggers(scheduleID: String, triggerIDs: Set<String>) async throws {
        stored.removeAll { $0.scheduleID == scheduleID && triggerIDs.contains($0.triggerID) }
    }
}
