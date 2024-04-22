/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class AutomationTriggerProcessorTest: XCTestCase, @unchecked Sendable {
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let store: TestTriggerStore = TestTriggerStore()
    private var processor: AutomationTriggerProcessor!

    override func setUp() async throws {
        self.processor = AutomationTriggerProcessor(store: store, date: date)
    }
    
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

        XCTAssertEqual(1, self.store.stored.count)
        try await restoreSchedules(trigger: trigger)
        XCTAssertEqual(0, self.store.stored.count)
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState(appSessionID: "foreground")))

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
        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .activeSession, goal: 1))

        await self.processor.processEvent(.stateChanged(state: TriggerableState()))
        
        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.stateChanged(state: TriggerableState(appSessionID: "foreground")))
        

        await self.processor.updateScheduleState(scheduleID: "schedule-id", state: .idle)

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
        
        XCTAssertEqual(
            TriggerData(
                scheduleID: "schedule-id",
                triggerID: "default-trigger",
                count: 1,
                children: [:]
            ),
            self.store.stored.last
        )
        
        await self.processor.cancel(scheduleIDs: ["schedule-id"])
        XCTAssert(self.store.stored.isEmpty)

        await self.processor.processEvent(.appInit)
        
        let result = await takeNext()
        XCTAssert(result.isEmpty)
    }
    
    func testCancelWithGroup() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id-2", type: .appInit, goal: 2))
        let schedule = defaultSchedule(trigger: trigger, group: "test-group")
        
        try await self.processor.restoreSchedules([schedule])
        await self.processor.processEvent(.appInit)
        
        XCTAssertEqual(
            TriggerData(
                scheduleID: "schedule-id",
                triggerID: "trigger-id-2",
                count: 1,
                children: [:]
            ),
            self.store.stored.last
        )

        await self.processor.cancel(group: "test-group")
        XCTAssert(self.store.stored.isEmpty)

        await self.processor.processEvent(.appInit)
        
        let result = await takeNext()
        XCTAssert(result.isEmpty)
    }
    
    func testProcessEventEmitsResults() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .appInit, goal: 1))

        try await restoreSchedules(trigger: trigger)
        
        await self.processor.processEvent(.appInit)
        
        XCTAssertEqual(
            TriggerData(
                scheduleID: "schedule-id",
                triggerID: "trigger-id",
                count: 0,
                children: [:]
            ),
            self.store.stored.last
        )

        let result = await takeNext()
        XCTAssertNotNil(result)
    }
    
    @MainActor
    func testProcessEventEmitsNothingOnPause() async throws {
        let trigger = AutomationTrigger.event(.init(id: "trigger-id", type: .appInit, goal: 1))

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
