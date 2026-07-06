/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct PreparedTriggerTest {
    let date = UATestDate(offset: 0, dateOverride: Date())
    
    @Test
    func testScheduleDatesUpdate() {
        var trigger = EventAutomationTrigger(type: .appInit, goal: 1)

        let instance = makeTrigger(trigger: .event(trigger))
        #expect(instance.startDate == nil)
        #expect(instance.endDate == nil)
        #expect(0 == instance.priority)

        trigger.goal = 3

        instance.update(trigger: .event(trigger), startDate: date.now, endDate: date.now, priority: 3)
        #expect(date.now == instance.startDate)
        #expect(date.now == instance.endDate)
        #expect(3 == instance.priority)
        #expect(.event(trigger) == instance.trigger)

    }
    
    @Test
    func testActivateTrigger() {
        let initialState = TriggerData(
            scheduleID: "test",
            triggerID: "trigger-id",
            count: 1,
            children: [:]
        )

        let execution = makeTrigger(type: .execution, state: initialState)
        #expect(!(execution.isActive))
        execution.activate()
        #expect(execution.isActive)
        #expect(initialState == execution.triggerData)

        let cancellation = makeTrigger(type: .delayCancellation, state: initialState)
        #expect(!(cancellation.isActive))
        cancellation.activate()
        #expect(cancellation.isActive)
        #expect(0 == cancellation.triggerData.count)
    }
    
    @Test
    func testDiable() {
        let instance = makeTrigger()
        #expect(!(instance.isActive))
        instance.activate()
        #expect(instance.isActive)
        instance.disable()
        #expect(!(instance.isActive))
    }
    
    @Test
    func testProcessEventHappyPath() throws {
        let trigger = EventAutomationTrigger(type: .appInit, goal: 2)
        let instance = makeTrigger(trigger: .event(trigger), type: .execution)
        instance.activate()
        
        #expect(0 == instance.triggerData.count)

        var result = instance.process(event: .event(type: .appInit))
        #expect(1 == result?.triggerData.count)
        #expect(result?.triggerResult == nil)

        result = instance.process(event: .event(type: .appInit))
        #expect(0 == result?.triggerData.count)

        let report = try #require(result?.triggerResult)
        #expect("test-schedule" == report.scheduleID)
        #expect(TriggerExecutionType.execution == report.triggerExecutionType)
        #expect(AirshipTriggerContext(type: "app_init", goal: 2, event: .null) == report.triggerInfo.context)
        #expect(date.now == report.triggerInfo.date)
    }
    
    @Test
    func testProcessEventDoesNothing() {
        let trigger = EventAutomationTrigger(type: .appInit, goal: 1)

        let instance = makeTrigger(trigger: .event(trigger))

        #expect(instance.process(event: .event(type: .appInit)) == nil)
        
        instance.activate()
        instance.update(
            trigger: .event(trigger),
            startDate: self.date.now.advanced(by: 1),
            endDate: nil,
            priority: 0
        )

        #expect(instance.process(event: .event(type: .appInit)) == nil)

        instance.update(
            trigger: .event(trigger),
            startDate: nil,
            endDate: nil,
            priority: 0
        )
        
        #expect(instance.process(event: .event(type: .appInit)) != nil)
    }
    
    @Test
    func testProcessEventDoesNothingForInvalidEventType() {
        let trigger = EventAutomationTrigger(type: .background, goal: 1)
        let instance = makeTrigger(trigger: .event(trigger))
        instance.activate()
        
        #expect(instance.process(event: .event(type: .foreground)) == nil)
        #expect(instance.process(event: .event(type: .background)) != nil)
    }
    
    @Test
    func testEventProcessingTypes() {
        let check: (EventAutomationTriggerType, AutomationEvent) -> TriggerData? = { type, event in
            let trigger = EventAutomationTrigger(type: type, goal: 3)
            let instance = self.makeTrigger(trigger: .event(trigger))
            instance.activate()
            let result = instance.process(event: event)
            return result?.triggerData
        }
        
        for eventType in EventAutomationTriggerType.allCases {
            let event = AutomationEvent.event(type: eventType, data: .null)
            #expect(1 == check(eventType, event)?.count)
        }
        
        #expect(2 == check(.customEventValue, .event(type: .customEventValue, data: .null, value: 2))?.count)
        #expect(2 == check(.customEventCount, .event(type: .customEventCount, data: .null, value: 2))?.count)
        
        let instance = makeTrigger()
        instance.activate()

        let state = TriggerableState(appSessionID: "session-id", versionUpdated: "123")
        let _ = instance.process(event: .stateChanged(state: state))
    }
    
    @Test
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
        
        var state = instance.process(event: .event(type: .background))
        #expect(state?.triggerResult == nil)

        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        
        var foreground = try #require(state?.triggerData.children["foreground"])
        #expect(1 == foreground.count)

        var appinit = try #require(state?.triggerData.children["init"])
        #expect(0 == appinit.count)

        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        
        /// Children reset once they are all triggered
        foreground = try #require(state?.triggerData.children["foreground"])
        #expect(0 == foreground.count)
        appinit = try #require(state?.triggerData.children["init"])
        #expect(0 == appinit.count)

        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)

        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult != nil)
    }
    
    @Test
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
        
        var state = instance.process(event: .event(type: .background))
        #expect(state?.triggerResult == nil)

        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        
        var foreground = try #require(state?.triggerData.children["foreground"])
        #expect(1 == foreground.count)

        var appinit = try #require(state?.triggerData.children["init"])
        #expect(0 == appinit.count)

        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        
        foreground = try #require(state?.triggerData.children["foreground"])
        #expect(0 == foreground.count) //1 because reset on increment is false

        appinit = try #require(state?.triggerData.children["init"])
        #expect(0 == appinit.count)

        _ = instance.process(event: .event(type: .appInit))
        state = instance.process(event: .event(type: .foreground))
        
        #expect(state?.triggerResult != nil)
    }
    
    @Test
    func testCompoundOrTrigger() throws {
        let trigger = AutomationTrigger.compound(
            CompoundAutomationTrigger(
                id: "simple-or",
                type: .or,
                goal: 2,
                children: [
                    .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2)), resetOnIncrement: true),
                    .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2)), resetOnIncrement: true),
                ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(0 == state?.triggerData.count)
        #expect(state?.triggerResult == nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(1 == state?.triggerData.count)
        #expect(state?.triggerResult == nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .foreground))
        #expect(1 == state?.triggerData.count)
        #expect(state?.triggerResult == nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .foreground))
        #expect(0 == state?.triggerData.count)
        #expect(state?.triggerResult != nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
    }
    
    
    
    @Test
    func testCompoundComplexOrTrigger() throws {
        let trigger = AutomationTrigger.compound(
            CompoundAutomationTrigger(
                id: "complex-or",
                type: .or,
                goal: 2,
                children: [
                    .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2)), resetOnIncrement: true),
                    .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2))),
                ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(0 == state?.triggerData.count)
        #expect(state?.triggerResult == nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(1 == state?.triggerData.count)
        #expect(state?.triggerResult == nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)

        state = instance.process(event: .event(type: .appInit))
        #expect(1 == state?.triggerData.count)
        #expect(state?.triggerResult == nil)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)

        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)

        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult != nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
    }
    
    @Test
    func testCompoundChainTrigger() {
        let trigger = AutomationTrigger.compound(CompoundAutomationTrigger(
            id: "simple-chain",
            type: .chain,
            goal: 2,
            children: [
                .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2)), isSticky: true),
                .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2))),
            ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(state?.triggerData == nil)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(state?.triggerData.count == nil)
        
        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)

        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)

        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult != nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
    }
    
    @Test
    func testCompoundChainTriggerWithChildState() throws {
        let trigger = AutomationTrigger.compound(CompoundAutomationTrigger(
            id: "state-child-chain",
            type: .chain,
            goal: 1,
            children: [
                .init(trigger: .event(EventAutomationTrigger(id: "custom-event", type: .customEventValue, goal: 1)), isSticky: true),
                .init(trigger: .activeSession(count: 1)),
            ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .stateChanged(state: TriggerableState(appSessionID: "test")))
        #expect(state?.triggerResult == nil)
        
        state = instance.process(event: .event(type: .customEventValue, data: .null, value: 1))
        #expect(state?.triggerResult != nil)
    }
    
    @Test
    func testCompoundComplexChainTrigger() {
        let trigger = AutomationTrigger.compound(CompoundAutomationTrigger(
            id: "complex-chain",
            type: .chain,
            goal: 2,
            children: [
                .init(trigger: .event(EventAutomationTrigger(id: "foreground", type: .foreground, goal: 2))),
                .init(trigger: .event(EventAutomationTrigger(id: "init", type: .appInit, goal: 2))),
            ]))
        
        let instance = makeTrigger(trigger: trigger)
        instance.activate()
        
        var state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(state?.triggerData == nil)
        
        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(state?.triggerData == nil)
        
        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 1)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(1 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 2)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 1)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult != nil)
        #expect(0 == state?.triggerData.count)
        assertChildDataCount(parent: state?.triggerData, triggerID: "foreground", count: 0)
        assertChildDataCount(parent: state?.triggerData, triggerID: "init", count: 0)
    }
    
    @Test
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
        
        var state = instance.process(event: .event(type: .foreground))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        
        state = instance.process(event: .event(type: .screen))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        
        state = instance.process(event: .event(type: .appInit))
        #expect(state?.triggerResult == nil)
        #expect(0 == state?.triggerData.count)
        
        state = instance.process(event: .event(type: .background))
        #expect(state?.triggerResult != nil)
        #expect(0 == state?.triggerData.count)
    }
    
    private func assertChildDataCount(parent: TriggerData?, triggerID: String, count: Double, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(count == parent?.children[triggerID]?.count, sourceLocation: sourceLocation)
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
