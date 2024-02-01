/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class AutomationTriggerProcessorTest: XCTestCase, @unchecked Sendable {
    let date = UATestDate(offset: 0, dateOverride: Date())
    let store = TestTriggerStore()
    var processor: AutomationTriggerProcessor!
    
    override func setUp() async throws {
        self.processor = AutomationTriggerProcessor(store: store, date: date)
    }
    
    func testRestoreSchedule() async throws {
        self.store.storedStates = [TriggerState(
            count: 0,
            goal: 2,
            scheduleID: "excluded-schedule-id",
            triggerID: "unused-trigger-id",
            children: [])]
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState(appSessionID: "foreground")))
        let trigger = AutomationTrigger(type: .activeSession, goal: 1, id: "trigger-id")
        
        XCTAssertEqual(1, self.store.storedStates.count)
        try await restoreSchedules(trigger: trigger)
        XCTAssertEqual(1, self.store.storedStates.count)
        XCTAssert(self.store.storedStates.contains(TriggerState(
            count: 0,
            goal: 1,
            scheduleID: "schedule-id",
            group: nil,
            triggerID: "trigger-id",
            children: [])))
        
        let result = await takeNext().first
        XCTAssertEqual("schedule-id", result?.scheduleID)
        XCTAssertEqual(TriggerExecutionType.execution, result?.triggerExecutionType)
        XCTAssertEqual(TriggeringInfo(
            context: AirshipTriggerContext(
                type: "active_session",
                goal: 1.0,
                event: .null),
            date: self.date.now), result?.triggerInfo)
    }
    
    func testUpdateTriggersResendsStatus() async throws {
        let trigger = AutomationTrigger(type: .activeSession, goal: 1, id: "trigger-id")
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState()))
        
        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState(appSessionID: "foreground")))
        
        try await self.processor.updateSchedule(defaultSchedule(trigger: trigger))
        
        let result = await takeNext(count: 2).last
        XCTAssertEqual("schedule-id", result?.scheduleID)
        XCTAssertEqual(TriggerExecutionType.execution, result?.triggerExecutionType)
        XCTAssertEqual(TriggeringInfo(
            context: AirshipTriggerContext(
                type: "active_session",
                goal: 1.0,
                event: .null),
            date: self.date.now), result?.triggerInfo)
    }
    
    func testCancelSchedule() async throws {
        
        try await restoreSchedules()
        
        await self.processor.processEvent(.appInit)
        
        XCTAssertEqual(TriggerState(
            count: 1,
            goal: 2,
            scheduleID: "schedule-id",
            group: nil,
            triggerID: "default-trigger",
            children: []), self.store.storedStates.last)
        
        await self.processor.cancel(scheduleIDs: ["schedule-id"])
        XCTAssert(self.store.storedStates.isEmpty)
        
        await self.processor.processEvent(.appInit)
        
        let result = await takeNext()
        XCTAssert(result.isEmpty)
    }
    
    func testCancelWithGroup() async throws {
        let trigger = AutomationTrigger(type: .appInit, goal: 2, id: "trigger-id-2")
        let schedule = defaultSchedule(trigger: trigger, group: "test-group")
        
        try await self.processor.restoreSchedules([schedule])
        await self.processor.processEvent(.appInit)
        
        XCTAssertEqual(TriggerState(
            count: 1,
            goal: 2,
            scheduleID: "schedule-id",
            group: "test-group",
            triggerID: "trigger-id-2",
            children: []), self.store.storedStates.last)
        
        await self.processor.cancel(group: "test-group")
        XCTAssert(self.store.storedStates.isEmpty)
        
        await self.processor.processEvent(.appInit)
        
        let result = await takeNext()
        XCTAssert(result.isEmpty)
    }
    
    func testProcessEventEmitsResults() async throws {
        let trigger = AutomationTrigger(type: .appInit, goal: 1, id: "trigger-id")
        
        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.appInit)
        
        XCTAssertEqual(TriggerState(
            count: 0,
            goal: 1,
            scheduleID: "schedule-id",
            group: nil,
            triggerID: "trigger-id",
            children: []), self.store.storedStates.last)
        
        let result = await takeNext()
        XCTAssertNotNil(result)
    }
    
    @MainActor
    func testProcessEventEmitsNothingOnPause() async throws {
        let trigger = AutomationTrigger(type: .appInit, goal: 1, id: "trigger-id")
        
        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.appInit)
        
        var result = await takeNext()
        XCTAssertNotNil(result)
        
        await self.processor.processEvent(.appInit)
        
        result = await takeNext()
        XCTAssertNotNil(result)
        
        self.processor.setPaused(true)
        
        await self.processor.processEvent(.appInit)
        
        result = await takeNext()
        XCTAssert(result.isEmpty)
    }
    
    /*
     @MainActor
     func setPaused(_ paused: Bool) {
         self.isPaused = paused
     }

     // check triggers for events
     func processEvent(_ event: AutomationEvent) async {
         guard await self.isPaused == false else { return }
         
         //save current state
         self.trackStateChange(event: event)
         
         var stateUpdates: [TriggerState] = []
         
         for trigger in self.preparedTriggers {
             guard
                 trigger.isActive,
                 let (state, result) = trigger.process(event: event)
             else { continue }
             
             stateUpdates.append(state)
             if let result = result {
                 self.continuation.yield(result)
             }
         }
         
         await self.store.save(states: stateUpdates)
     }
     */
    
    private func restoreSchedules(trigger: AutomationTrigger? = nil) async throws {
        let trigger = trigger ?? AutomationTrigger(type: .appInit, goal: 2, id: "default-trigger")
        
        let schedule = defaultSchedule(trigger: trigger)
        
        try await self.processor.restoreSchedules([schedule])
    }
    
    private func defaultSchedule(trigger: AutomationTrigger, group: String? = nil) -> AutomationScheduleData {
        return AutomationScheduleData(
            identifier: "schedule-data-id",
            group: group,
            startDate: self.date.now,
            endDate: self.date.now,
            schedule: AutomationSchedule(
                identifier: "schedule-id",
                data: .actions(.null),
                triggers: [trigger],
                group: group
            ),
            scheduleState: .idle,
            scheduleStateChangeDate: self.date.now)
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
        
        do {
            let result = try await collectTask.result.get()
            cancel.cancel()
            return result
        } catch {
            print("failed to get results \(error)")
            return []
        }
    }
}

final class TestTriggerStore: TriggerStoreProtocol, @unchecked Sendable {
    
    var storedStates: [TriggerState] = []
    
    func savedTriggerState(triggerID: String) async -> AirshipAutomationSwift.TriggerState? {
        return storedStates.first(where: { $0.triggerID == triggerID })
    }
    
    func saveTriggerStates(states: [AirshipAutomationSwift.TriggerState]) async {
        storedStates.append(contentsOf: states)
    }
    
    func removeAllTriggerStates(excluding scheduleIDs: Set<String>) async {
        storedStates.removeAll(where: { !scheduleIDs.contains($0.scheduleID) })
    }
    
    func removeTriggerStatesFor(scheduleIDs: [String]) async {
        storedStates.removeAll(where: { scheduleIDs.contains($0.scheduleID) })
    }
    
    func removeTriggerStateFor(group: String) async {
        storedStates.removeAll(where: { $0.group == group })
    }
}
