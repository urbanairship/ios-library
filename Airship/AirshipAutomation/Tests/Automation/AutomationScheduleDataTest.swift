/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore


struct AutomationScheduleDataTest {
    

    private let date: Date = Date()
    private let triggerInfo: TriggeringInfo = TriggeringInfo(
        context: nil, 
        date: Date()
    )

    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0)

    private var data: AutomationScheduleData

    init() {
        self.data = AutomationScheduleData(
            schedule: AutomationSchedule(
                identifier: "neat",
                triggers: [],
                data: .actions(.string("actions"))
            ),
            scheduleState: .idle,
            lastScheduleModifiedDate: self.date,
            scheduleStateChangeDate: self.date,
            executionCount: 0,
            triggerSessionID: UUID().uuidString
        )
    }

    @Test
    func testIsInState() throws {
        #expect(data.isInState([.idle]))
        #expect(!(data.isInState([])))
        #expect(!(data.isInState([.executing])))
        #expect(!(data.isInState([.executing, .finished, .prepared, .paused])))
        #expect(data.isInState([.idle, .executing, .finished, .prepared, .paused]))
    }

    @Test
    mutating func testIsActive() throws {
        // no start or end
        #expect(data.isActive(date: self.date))

        // starts in the future
        self.data.schedule.start = self.date + 1
        #expect(!(data.isActive(date: self.date)))

        // starts now
        self.data.schedule.start = self.date
        #expect(data.isActive(date: self.date))

        // ends in the past
        self.data.schedule.end = self.date - 1
        #expect(!(data.isActive(date: self.date)))

        // ends now
        self.data.schedule.end = self.date
        #expect(!(data.isActive(date: self.date)))

        // ends in the future
        self.data.schedule.end = self.date + 1
        #expect(data.isActive(date: self.date))
    }

    @Test
    mutating func testIsExpired() throws {
        // no end set
        #expect(!(data.isExpired(date: self.date)))

        // ends in the past
        self.data.schedule.end = self.date - 1
        #expect(data.isExpired(date: self.date))

        // ends now
        self.data.schedule.end = self.date
        #expect(data.isExpired(date: self.date))

        // ends in the future
        self.data.schedule.end = self.date + 1
        #expect(!(data.isExpired(date: self.date)))
    }

    @Test
    mutating func testOverLimitNotSetDefaultsTo1() throws {
        self.data.schedule.limit = nil

        self.data.executionCount = 0
        #expect(!(data.isOverLimit))

        self.data.executionCount = 1
        #expect(data.isOverLimit)
    }

    @Test
    mutating func testOverLimitUnlimited() throws {
        self.data.schedule.limit = 0

        self.data.executionCount = 0
        #expect(!(data.isOverLimit))

        self.data.executionCount = 1
        #expect(!(data.isOverLimit))

        self.data.executionCount = 100
        #expect(!(data.isOverLimit))
    }

    @Test
    mutating func testOverLimit() throws {
        self.data.schedule.limit = 10

        self.data.executionCount = 0
        #expect(!(data.isOverLimit))

        self.data.executionCount = 9
        #expect(!(data.isOverLimit))

        self.data.executionCount = 10
        #expect(data.isOverLimit)

        self.data.executionCount = 11
        #expect(data.isOverLimit)
    }

    @Test
    mutating func testFinished() {
        self.data.triggerInfo = self.triggerInfo
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.finished(date: self.date + 100)

        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.triggerInfo == nil)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testIdle() {
        self.data.scheduleState = .finished
        self.data.triggerInfo = self.triggerInfo
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.idle(date: self.date + 100)

        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.triggerInfo == nil)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPaused() {
        self.data.triggerInfo = self.triggerInfo
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.paused(date: self.date + 100)

        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.triggerInfo == nil)
        #expect(self.data.scheduleState == .paused)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testUpdateStateFinishesOverLimit() {
        self.data.scheduleState = .idle
        self.data.executionCount = 1
        self.data.schedule.limit = 1

        self.data.updateState(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testUpdateStateExpired() {
        self.data.scheduleState = .idle
        self.data.schedule.end = self.date

        self.data.updateState(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testUpdateFinishedToIdle() {
        self.data.scheduleState = .finished

        self.data.updateState(date: self.date + 100)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testUpdateStateFinished() {
        self.data.scheduleState = .idle

        self.data.updateState(date: self.date + 100)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.scheduleStateChangeDate == self.date)
    }

    @Test
    mutating func testPrepareCancelledPenalize() {
        self.data.schedule.limit = 2
        self.data.scheduleState = .triggered

        self.data.prepareCancelled(date: self.date + 100, penalize: true)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.executionCount == 1)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)

    }

    @Test
    mutating func testPrepareCancelled() {
        self.data.scheduleState = .triggered

        self.data.prepareCancelled(date: self.date + 100, penalize: false)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.executionCount == 0)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPrepareCancelledOverLimit() {
        self.data.scheduleState = .triggered

        self.data.prepareCancelled(date: self.date + 100, penalize: true)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 1)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPrepareCancelledExpired() {
        self.data.schedule.limit = 2
        self.data.scheduleState = .triggered
        self.data.schedule.end = self.date

        self.data.prepareCancelled(date: self.date + 100, penalize: true)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 1)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPrepareInterrupted() {
        self.data.scheduleState = .prepared

        self.data.prepareInterrupted(date: self.date + 100)
        #expect(self.data.scheduleState == .triggered)
        #expect(self.data.executionCount == 0)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testTriggeredScheduleInterrupted() {
        self.data.scheduleState = .triggered

        self.data.prepareInterrupted(date: self.date + 100)
        #expect(self.data.scheduleState == .triggered)
        #expect(self.data.executionCount == 0)
        #expect(self.data.scheduleStateChangeDate == self.date)
    }

    @Test
    mutating func testPrepareInterruptedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .triggered

        self.data.prepareInterrupted(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPrepareInterruptedExpired() {
        self.data.scheduleState = .triggered
        self.data.schedule.end = self.date

        self.data.prepareInterrupted(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 0)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionCancelled() {
        self.data.scheduleState = .prepared

        self.data.executionCancelled(date: self.date + 100)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.executionCount == 0)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionCancelledOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionCancelled(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionCancelledExpired() {
        self.data.scheduleState = .prepared
        self.data.schedule.end = self.date

        self.data.executionCancelled(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPrepared() {
        self.data.scheduleState = .triggered

        self.data.prepared(info: self.preparedScheduleInfo, date: self.date + 100)
        #expect(self.data.scheduleState == .prepared)
        #expect(self.data.preparedScheduleInfo == self.preparedScheduleInfo)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPreparedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .triggered

        self.data.prepared(info: self.preparedScheduleInfo, date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testPreparedExpired() {
        self.data.schedule.end = self.date
        self.data.scheduleState = .triggered

        self.data.prepared(info: self.preparedScheduleInfo, date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionSkipped() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionSkipped(date: self.date + 100)
        #expect(self.data.executionCount == 1)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionSkippedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionSkipped(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionSkippedExpired() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.end = self.date
        self.data.scheduleState = .prepared

        self.data.executionSkipped(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInvalidated() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionInvalidated(date: self.date + 100)
        #expect(self.data.scheduleState == .triggered)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInvalidatedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionInvalidated(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInvalidatedExpired() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.end = self.date
        self.data.scheduleState = .prepared

        self.data.executionInvalidated(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecuting() {
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executing(date: self.date + 100)
        #expect(self.data.scheduleState == .executing)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInterrupted() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing

        self.data.executionInterrupted(date: self.date + 100, retry: false)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.executionCount == 2)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInterruptedRetry() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.schedule.end = self.date

        self.data.executionInterrupted(date: self.date + 100, retry: true)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 1)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInterruptedOverLimit() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.executionInterrupted(date: self.date + 100, retry: false)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 2)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInterruptedExpired() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.schedule.end = self.date

        self.data.executionInterrupted(date: self.date + 100, retry: true)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 1)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testExecutionInterruptedInterval() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing
        self.data.schedule.interval = 10.0
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.executionInterrupted(date: self.date + 100, retry: false)
        #expect(self.data.scheduleState == .paused)
        #expect(self.data.executionCount == 2)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }


    @Test
    mutating func testFinishedExecuting() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.finishedExecuting(date: self.date + 100)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleState == .idle)
        #expect(self.data.executionCount == 2)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testFinishedExecutingOverLimit() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.finishedExecuting(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 2)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testFinishedExecutingExpired() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.schedule.end = self.date

        self.data.finishedExecuting(date: self.date + 100)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.executionCount == 2)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testFinishedExecutingInterval() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing
        self.data.schedule.interval = 10.0
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.finishedExecuting(date: self.date + 100)
        #expect(self.data.scheduleState == .paused)
        #expect(self.data.executionCount == 2)
        #expect(self.data.preparedScheduleInfo == nil)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testShouldDelete() {
        #expect(!(self.data.shouldDelete(date: self.date)))


        self.data.scheduleState = .finished
        #expect(self.data.shouldDelete(date: self.date))

        self.data.schedule.editGracePeriodDays = 10
        #expect(!(self.data.shouldDelete(date: self.date)))
        #expect(!(self.data.shouldDelete(date: self.date + 10 * 60 * 60 * 24 - 1)))
        #expect(self.data.shouldDelete(date: self.date + 10 * 60 * 60 * 24))
    }

    @Test
    mutating func testTriggered() {
        let previousTriggerSessionID = self.data.triggerSessionID

        let context = AirshipTriggerContext(type: "some-type", goal: 10.0, event: "event")
        
        self.data.triggered(triggerInfo: TriggeringInfo(context: context, date: self.date), date: self.date + 100)
        #expect(self.data.triggerInfo?.context == context)
        #expect(self.data.triggerInfo?.date == self.date)
        #expect(self.data.scheduleState == .triggered)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
        #expect(self.data.triggerSessionID != previousTriggerSessionID)
    }

    @Test
    mutating func testTriggeredOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1

        let context = AirshipTriggerContext(type: "some-type", goal: 10.0, event: "event")
        self.data.triggered(triggerInfo: TriggeringInfo(context: context, date: self.date), date: self.date + 100)

        #expect(self.data.triggerInfo == nil)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }

    @Test
    mutating func testTriggeredExpired() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.end = self.date

        let context = AirshipTriggerContext(type: "some-type", goal: 10.0, event: "event")
        self.data.triggered(triggerInfo: TriggeringInfo(context: context, date: self.date), date: self.date + 100)

        #expect(self.data.triggerInfo == nil)
        #expect(self.data.scheduleState == .finished)
        #expect(self.data.scheduleStateChangeDate == self.date + 100)
    }
}
