/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class PreparedTriggerTest: XCTestCase {
    let date = UATestDate(offset: 0, dateOverride: Date())
    
    func testScheduleDatesUpdate() {
        var trigger = EventAutomationTrigger(type: .appInit, goal: 1)

        let instance = makeTrigger(trigger: .event(trigger))
        XCTAssertNil(instance.startDate)
        XCTAssertNil(instance.endDate)
        XCTAssertEqual(0, instance.priority)

        trigger.goal = 3

        instance.update(trigger: .event(trigger), startDate: date.now, endDate: date.now, priority: 3)
        XCTAssertEqual(date.now, instance.startDate)
        XCTAssertEqual(date.now, instance.endDate)
        XCTAssertEqual(3, instance.priority)
        XCTAssertEqual(.event(trigger), instance.trigger)

    }
    
    func testActivateTrigger() {
        let initialState = TriggerData(
            scheduleID: "test",
            triggerID: "trigger-id",
            count: 1,
            children: [:]
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
        let trigger = EventAutomationTrigger(type: .appInit, goal: 2)
        let instance = makeTrigger(trigger: .event(trigger), type: .execution)
        instance.activate()
        
        XCTAssertEqual(0, instance.triggerData.count)

        var result = instance.process(event: .appInit)
        XCTAssertEqual(1, result?.triggerData.count)
        XCTAssertNil(result?.triggerResult)

        result = instance.process(event: .appInit)
        XCTAssertEqual(0, result?.triggerData.count)

        let report = try XCTUnwrap(result?.triggerResult)
        XCTAssertEqual("test-schedule", report.scheduleID)
        XCTAssertEqual(TriggerExecutionType.execution, report.triggerExecutionType)
        XCTAssertEqual(AirshipTriggerContext(type: "app_init", goal: 2, event: .null), report.triggerInfo.context)
        XCTAssertEqual(date.now, report.triggerInfo.date)
    }
    
    func testProcessEventDoesNothing() {
        let trigger = EventAutomationTrigger(type: .appInit, goal: 1)

        let instance = makeTrigger(trigger: .event(trigger))

        XCTAssertNil(instance.process(event: .appInit))
        
        instance.activate()
        instance.update(
            trigger: .event(trigger),
            startDate: self.date.now.addingTimeInterval(1),
            endDate: nil,
            priority: 0
        )

        XCTAssertNil(instance.process(event: .appInit))

        instance.update(
            trigger: .event(trigger),
            startDate: nil,
            endDate: nil,
            priority: 0
        )
        
        XCTAssertNotNil(instance.process(event: .appInit))
    }
    
    func testProcessEventDoesNothingForInvalidEventType() {
        let trigger = EventAutomationTrigger(type: .background, goal: 1)
        let instance = makeTrigger(trigger: .event(trigger))
        instance.activate()
        
        XCTAssertNil(instance.process(event: .foreground))
        XCTAssertNotNil(instance.process(event: .background))
    }
    
    func testEventProcessingTypes() {
        let check: (EventAutomationTriggerType, AutomationEvent) -> TriggerData? = { type, event in
            let trigger = EventAutomationTrigger(type: type, goal: 3)
            let instance = self.makeTrigger(trigger: .event(trigger))
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
        

        let state = TriggerableState(appSessionID: "session-id", versionUpdated: "123")
        let _ = instance.process(event: .stateChanged(state: state))
    }
    
    func testCompoundAndTrigger() throws {
        let trigger = AutomationTrigger.compound(
            .init(
                id: "compound",
                type: .and,
                goal: 2,
                children: [
                    .init(trigger: .event(.init(id: "foreground", type: .foreground, goal: 1))),
                    .init(trigger: .event(.init(id: "init", type: .appInit, goal: 1)))
                ]
            )
        )
        
        let instance = makeTrigger(trigger: trigger)
        
        instance.activate()
        
        var state = instance.process(event: .background)
        XCTAssertNil(state?.triggerResult)

        state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        var foreground = try XCTUnwrap(state?.triggerData.children["foreground"])
        XCTAssertEqual(1, foreground.count)

        var appinit = try XCTUnwrap(state?.triggerData.children["init"])
        XCTAssertEqual(0, appinit.count)

        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        
        foreground = try XCTUnwrap(state?.triggerData.children["foreground"])
        XCTAssertEqual(1, foreground.count) //1 because reset on increment is false

        appinit = try XCTUnwrap(state?.triggerData.children["init"])
        XCTAssertEqual(1, appinit.count)

        //this is a little weird. we have an `and` trigger with `resetOnIncrement` = flase
        // which means if goal is 2, we don't need a second app init event to fire
        state = instance.process(event: .foreground)
        
        XCTAssertNotNil(state?.triggerResult)
    }
    
    func testCompoundAndComplexTrigger() throws {
        let trigger = AutomationTrigger.compound(
            .init(
                id: "compound",
                type: .and,
                goal: 2,
                children: [
                    .init(trigger: .event(.init(id: "foreground", type: .foreground, goal: 1)), resetOnIncrement: true),
                    .init(trigger: .event(.init(id: "init", type: .appInit, goal: 1)), resetOnIncrement: true)
                ]
            )
        )
        
        let instance = makeTrigger(trigger: trigger)
        
        instance.activate()
        
        var state = instance.process(event: .background)
        XCTAssertNil(state?.triggerResult)

        state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        var foreground = try XCTUnwrap(state?.triggerData.children["foreground"])
        XCTAssertEqual(1, foreground.count)

        var appinit = try XCTUnwrap(state?.triggerData.children["init"])
        XCTAssertEqual(0, appinit.count)

        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        
        foreground = try XCTUnwrap(state?.triggerData.children["foreground"])
        XCTAssertEqual(0, foreground.count) //1 because reset on increment is false

        appinit = try XCTUnwrap(state?.triggerData.children["init"])
        XCTAssertEqual(0, appinit.count)

        _ = instance.process(event: .appInit)
        state = instance.process(event: .foreground)
        
        XCTAssertNotNil(state?.triggerResult)
    }
    
    func testCompoundOrTrigger() throws {
        let trigger = AutomationTrigger.compound(
            CompoundAutomationTrigger(
                id: "simple-or",
                type: .or,
                goal: 2,
                children: [
                    .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2))),
                    .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2))),
                ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertEqual(0, state?.triggerData.count)
        XCTAssertNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .appInit)
        XCTAssertEqual(1, state?.triggerData.count)
        XCTAssertNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .foreground)
        XCTAssertEqual(1, state?.triggerData.count)
        XCTAssertNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .foreground)
        XCTAssertEqual(0, state?.triggerData.count)
        XCTAssertNotNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
    }
    
    func testCompoundComplexOrTrigger() throws {
        let trigger = AutomationTrigger.compound(
            CompoundAutomationTrigger(
                id: "complex-or",
                type: .or,
                goal: 2,
                children: [
                    .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2, resetOnFire: true)), isSticky: true),
                    .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2, resetOnFire: true)), isSticky: true),
                ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertEqual(0, state?.triggerData.count)
        XCTAssertNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .appInit)
        XCTAssertEqual(1, state?.triggerData.count)
        XCTAssertNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .foreground)
        XCTAssertEqual(1, state?.triggerData.count)
        XCTAssertNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .foreground)
        XCTAssertEqual(0, state?.triggerData.count)
        XCTAssertNotNil(state?.triggerResult)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
    }
    
    func testCompoundChainTrigger() {
        let trigger = AutomationTrigger.compound(CompoundAutomationTrigger(
            id: "simple-chain",
            type: .chain,
            goal: 2,
            children: [
                .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2))),
                .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2))),
            ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertNil(state?.triggerData)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertNil(state?.triggerData.count)
        
        state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 2)
        
        state = instance.process(event: .appInit)
        XCTAssertNotNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 3)
    }
    
    func testCompoundComplexChainTrigger() {
        let trigger = AutomationTrigger.compound(CompoundAutomationTrigger(
            id: "complex-chain",
            type: .chain,
            goal: 2,
            children: [
                .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2)), resetOnIncrement: true),
                .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2)), resetOnIncrement: true),
            ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertNil(state?.triggerData)
        
        state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertNil(state?.triggerData)
        
        state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(1, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .appInit)
        XCTAssertNotNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
    }
    
    func testComplexTrigger() {
        let trigger = AutomationTrigger.compound(
            CompoundAutomationTrigger(
                id: "complex-trigger",
                type: .and,
                goal: 1,
                children: [
                    .init(trigger: AutomationTrigger.compound(
                        CompoundAutomationTrigger(
                            id: "foreground-or-init",
                            type: .or,
                            goal: 1,
                            children: [
                                .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 1))),
                                .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 1)))
                            ])
                    )),
                    .init(trigger: AutomationTrigger.compound(
                        CompoundAutomationTrigger(
                            id: "chain-screen-background",
                            type: .chain,
                            goal: 1,
                            children: [
                                .init(trigger: .event(EventAutomationTrigger(id: "screen", type: .screen, goal: 1))),
                                .init(trigger: .event(EventAutomationTrigger(id: "background", type: .background, goal: 1)))
                            ])
                    ))
                ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .foreground)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        state = instance.process(event: .screenView(name: nil))
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        state = instance.process(event: .appInit)
        XCTAssertNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
        
        state = instance.process(event: .background)
        XCTAssertNotNil(state?.triggerResult)
        XCTAssertEqual(0, state?.triggerData.count)
    }
    
    private func assertChildDataCount(parent: TriggerData?, triggerID: String, count: Double) {
        XCTAssertEqual(count, parent?.children[triggerID]?.count)
    }
    
    private func makeTrigger(trigger: AutomationTrigger? = nil, type: TriggerExecutionType = .execution, startDate: Date? = nil, endDate: Date? = nil, state: TriggerData? = nil) -> PreparedTrigger {
        let trigger = trigger ?? AutomationTrigger.event(.init(type: .appInit, goal: 1))

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
