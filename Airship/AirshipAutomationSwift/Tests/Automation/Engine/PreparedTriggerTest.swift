/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class PreparedTriggerTest: XCTestCase {
    let date = UATestDate(offset: 0, dateOverride: Date())
    
    func testScheduleDatesUpdate() {
        var trigger = AutomationTrigger(type: .appInit, goal: 1)

        let instance = makeTrigger(trigger: trigger)
        XCTAssertNil(instance.startDate)
        XCTAssertNil(instance.endDate)
        XCTAssertEqual(0, instance.priority)

        trigger.goal = 3

        instance.update(trigger: trigger, startDate: date.now, endDate: date.now, priority: 3)
        XCTAssertEqual(date.now, instance.startDate)
        XCTAssertEqual(date.now, instance.endDate)
        XCTAssertEqual(3, instance.priority)
        XCTAssertEqual(trigger, instance.trigger)

    }
    
    func testActivateTrigger() {
        let initialState = TriggerData(
            scheduleID: "test",
            triggerID: "trigger-id",
            goal: 2,
            count: 1
        )

        let execution = makeTrigger(type: .execution, state: initialState)
        XCTAssertFalse(execution.isActive)
        execution.activate()
        XCTAssert(execution.isActive)
        XCTAssertEqual(initialState, execution.triggerData)

        let cancellation = makeTrigger(type: .delayCancellation, state: initialState)
        XCTAssertFalse(cancellation.isActive)
        cancellation.activate()
        XCTAssert(cancellation.isActive)
        XCTAssertNotEqual(initialState, cancellation.triggerData)
        XCTAssertEqual(0, cancellation.triggerData.count)
    }
    
    func testDiable() {
        let instance = makeTrigger()
        XCTAssertFalse(instance.isActive)
        instance.activate()
        XCTAssert(instance.isActive)
        instance.disable()
        XCTAssertFalse(instance.isActive)
    }
    
    func testProcessEventHappyPath() throws {
        let instance = makeTrigger(trigger: AutomationTrigger(type: .appInit, goal: 2), type: .execution)
        instance.activate()
        
        XCTAssertEqual(0, instance.triggerData.count)

        var result = instance.process(event: .appInit)
        XCTAssertEqual(1, result?.triggerData.count)
        XCTAssertNil(result?.triggerResult)
        XCTAssert(result?.triggerData.isGoalReached == false)

        result = instance.process(event: .appInit)
        XCTAssertEqual(0, result?.triggerData.count)
        XCTAssert(result?.triggerData.isGoalReached == false)

        let report = try XCTUnwrap(result?.triggerResult)
        XCTAssertEqual("test-schedule", report.scheduleID)
        XCTAssertEqual(TriggerExecutionType.execution, report.triggerExecutionType)
        XCTAssertEqual(AirshipTriggerContext(type: "app_init", goal: 2, event: .null), report.triggerInfo.context)
        XCTAssertEqual(date.now, report.triggerInfo.date)
    }
    
    func testProcessEventDoesNothing() {
        let trigger = AutomationTrigger(type: .appInit, goal: 1)

        let instance = makeTrigger(trigger: trigger)

        XCTAssertNil(instance.process(event: .appInit))
        
        instance.activate()
        instance.update(
            trigger: trigger,
            startDate: self.date.now.addingTimeInterval(1),
            endDate: nil,
            priority: 0
        )

        XCTAssertNil(instance.process(event: .appInit))

        instance.update(
            trigger: trigger,
            startDate: nil,
            endDate: nil,
            priority: 0
        )
        
        XCTAssertNotNil(instance.process(event: .appInit))
    }
    
    func testProcessEventDoesNothingForInvalidEventType() {
        let instance = makeTrigger(trigger: AutomationTrigger(type: .background, goal: 1))
        instance.activate()
        
        XCTAssertNil(instance.process(event: .foreground))
        XCTAssertNotNil(instance.process(event: .background))
    }
    
    func testEventProcessingTypes() {
        let check: (AutomationTriggerType, AutomationEvent) -> TriggerData? = { type, event in
            let trigger = AutomationTrigger(type: type, goal: 3)
            let instance = self.makeTrigger(trigger: trigger)
            instance.activate()
            let result = instance.process(event: event)
            return result?.triggerData
        }
        
        XCTAssertEqual(1, check(.foreground, .foreground)?.count)
        XCTAssertEqual(1, check(.background, .background)?.count)
        XCTAssertEqual(1, check(.appInit, .appInit)?.count)
        XCTAssertEqual(1, check(.screen, .screenView(name: nil))?.count)
        XCTAssertEqual(1, check(.regionEnter, .regionEnter(regionId: "reg"))?.count)
        XCTAssertEqual(1, check(.regionExit, .regionExit(regionId: "regid"))?.count)
        XCTAssertEqual(1, check(.featureFlagInteraction, .featureFlagInterracted(data: .null))?.count)
        XCTAssertEqual(2, check(.customEventValue, .customEvent(data: .null, value: 2))?.count)
        XCTAssertEqual(1, check(.customEventCount, .customEvent(data: .null, value: 2))?.count)
        
        XCTAssertNil(check(.version, .stateChanged(state: TriggerableState())))
        XCTAssertEqual(1, check(.version, .stateChanged(state: TriggerableState(versionUpdated: "1.2.3")))?.count)
        
        XCTAssertNil(check(.activeSession, .stateChanged(state: TriggerableState())))
        XCTAssertEqual(1, check(.activeSession, .stateChanged(state: TriggerableState(appSessionID: "session-id")))?.count)
        
        let instance = makeTrigger()
        instance.activate()
        
        XCTAssertNil(instance.appState)
        
        let state = TriggerableState(appSessionID: "session-id", versionUpdated: "123")
        let _ = instance.process(event: .stateChanged(state: state))
        XCTAssertEqual(state, instance.appState)
    }
    
    
    private func makeTrigger(trigger: AutomationTrigger? = nil, type: TriggerExecutionType = .execution, startDate: Date? = nil, endDate: Date? = nil, state: TriggerData? = nil) -> PreparedTrigger {
        let trigger = trigger ?? AutomationTrigger(type: .appInit, goal: 1)
        
        return PreparedTrigger(
            scheduleID: "test-schedule",
            trigger: trigger,
            type: type, 
            startDate: startDate,
            endDate: endDate,
            triggerData: state,
            priority: 0,
            date: date
        )
    }
}
