/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore


final class AutomationScheduleDataTest: XCTestCase {
    

    private let date: Date = Date()
    private let triggerInfo: TriggeringInfo = TriggeringInfo(
        context: nil, 
        date: Date()
    )

    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0)

    private var data: AutomationScheduleData!

    override func setUp() async throws {
        self.data = AutomationScheduleData(
            schedule: AutomationSchedule(
                identifier: "neat",
                triggers: [],
                data: .actions(.string("actions"))
            ),
            scheduleState: .idle,
            scheduleStateChangeDate: self.date,
            executionCount: 0,
            triggerSessionID: UUID().uuidString
        )
    }

    func testIsInState() throws {
        XCTAssertTrue(data.isInState([.idle]))
        XCTAssertFalse(data.isInState([]))
        XCTAssertFalse(data.isInState([.executing]))
        XCTAssertFalse(data.isInState([.executing, .finished, .prepared, .paused]))
        XCTAssertTrue(data.isInState([.idle, .executing, .finished, .prepared, .paused]))
    }

    func testIsActive() throws {
        // no start or end
        XCTAssertTrue(data.isActive(date: self.date))

        // starts in the future
        self.data.schedule.start = self.date + 1
        XCTAssertFalse(data.isActive(date: self.date))

        // starts now
        self.data.schedule.start = self.date
        XCTAssertTrue(data.isActive(date: self.date))

        // ends in the past
        self.data.schedule.end = self.date - 1
        XCTAssertFalse(data.isActive(date: self.date))

        // ends now
        self.data.schedule.end = self.date
        XCTAssertFalse(data.isActive(date: self.date))

        // ends in the future
        self.data.schedule.end = self.date + 1
        XCTAssertTrue(data.isActive(date: self.date))
    }

    func testIsExpired() throws {
        // no end set
        XCTAssertFalse(data.isExpired(date: self.date))

        // ends in the past
        self.data.schedule.end = self.date - 1
        XCTAssertTrue(data.isExpired(date: self.date))

        // ends now
        self.data.schedule.end = self.date
        XCTAssertTrue(data.isExpired(date: self.date))

        // ends in the future
        self.data.schedule.end = self.date + 1
        XCTAssertFalse(data.isExpired(date: self.date))
    }

    func testOverLimitNotSetDefaultsTo1() throws {
        self.data.schedule.limit = nil

        self.data.executionCount = 0
        XCTAssertFalse(data.isOverLimit)

        self.data.executionCount = 1
        XCTAssertTrue(data.isOverLimit)
    }

    func testOverLimitUnlimited() throws {
        self.data.schedule.limit = 0

        self.data.executionCount = 0
        XCTAssertFalse(data.isOverLimit)

        self.data.executionCount = 1
        XCTAssertFalse(data.isOverLimit)

        self.data.executionCount = 100
        XCTAssertFalse(data.isOverLimit)
    }

    func testOverLimit() throws {
        self.data.schedule.limit = 10

        self.data.executionCount = 0
        XCTAssertFalse(data.isOverLimit)

        self.data.executionCount = 9
        XCTAssertFalse(data.isOverLimit)

        self.data.executionCount = 10
        XCTAssertTrue(data.isOverLimit)

        self.data.executionCount = 11
        XCTAssertTrue(data.isOverLimit)
    }

    func testFinished() {
        self.data.triggerInfo = self.triggerInfo
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.finished(date: self.date + 100)

        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertNil(self.data.triggerInfo)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testIdle() {
        self.data.scheduleState = .finished
        self.data.triggerInfo = self.triggerInfo
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.idle(date: self.date + 100)

        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertNil(self.data.triggerInfo)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPaused() {
        self.data.triggerInfo = self.triggerInfo
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.paused(date: self.date + 100)

        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertNil(self.data.triggerInfo)
        XCTAssertEqual(self.data.scheduleState, .paused)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testUpdateStateFinishesOverLimit() {
        self.data.scheduleState = .idle
        self.data.executionCount = 1
        self.data.schedule.limit = 1

        self.data.updateState(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testUpdateStateExpired() {
        self.data.scheduleState = .idle
        self.data.schedule.end = self.date

        self.data.updateState(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testUpdateFinishedToIdle() {
        self.data.scheduleState = .finished

        self.data.updateState(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testUpdateStateFinished() {
        self.data.scheduleState = .idle

        self.data.updateState(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date)
    }

    func testPrepareCancelledPenalize() {
        self.data.schedule.limit = 2
        self.data.scheduleState = .triggered

        self.data.prepareCancelled(date: self.date + 100, penalize: true)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.executionCount, 1)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)

    }

    func testPrepareCancelled() {
        self.data.scheduleState = .triggered

        self.data.prepareCancelled(date: self.date + 100, penalize: false)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.executionCount, 0)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPrepareCancelledOverLimit() {
        self.data.scheduleState = .triggered

        self.data.prepareCancelled(date: self.date + 100, penalize: true)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 1)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPrepareCancelledExpired() {
        self.data.schedule.limit = 2
        self.data.scheduleState = .triggered
        self.data.schedule.end = self.date

        self.data.prepareCancelled(date: self.date + 100, penalize: true)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 1)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPrepareInterrupted() {
        self.data.scheduleState = .prepared

        self.data.prepareInterrupted(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .triggered)
        XCTAssertEqual(self.data.executionCount, 0)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testTriggeredScheduleInterrupted() {
        self.data.scheduleState = .triggered

        self.data.prepareInterrupted(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .triggered)
        XCTAssertEqual(self.data.executionCount, 0)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date)
    }

    func testPrepareInterruptedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .triggered

        self.data.prepareInterrupted(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPrepareInterruptedExpired() {
        self.data.scheduleState = .triggered
        self.data.schedule.end = self.date

        self.data.prepareInterrupted(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 0)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionCancelled() {
        self.data.scheduleState = .prepared

        self.data.executionCancelled(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.executionCount, 0)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionCancelledOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionCancelled(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionCancelledExpired() {
        self.data.scheduleState = .prepared
        self.data.schedule.end = self.date

        self.data.executionCancelled(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPrepared() {
        self.data.scheduleState = .triggered

        self.data.prepared(info: self.preparedScheduleInfo, date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .prepared)
        XCTAssertEqual(self.data.preparedScheduleInfo, self.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPreparedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .triggered

        self.data.prepared(info: self.preparedScheduleInfo, date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testPreparedExpired() {
        self.data.schedule.end = self.date
        self.data.scheduleState = .triggered

        self.data.prepared(info: self.preparedScheduleInfo, date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionSkipped() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionSkipped(date: self.date + 100)
        XCTAssertEqual(self.data.executionCount, 1)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionSkippedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionSkipped(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionSkippedExpired() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.end = self.date
        self.data.scheduleState = .prepared

        self.data.executionSkipped(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInvalidated() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionInvalidated(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .triggered)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInvalidatedOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executionInvalidated(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInvalidatedExpired() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.end = self.date
        self.data.scheduleState = .prepared

        self.data.executionInvalidated(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecuting() {
        self.data.executionCount = 1
        self.data.scheduleState = .prepared

        self.data.executing(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .executing)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInterrupted() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing

        self.data.executionInterrupted(date: self.date + 100, retry: false)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInterruptedRetry() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.schedule.end = self.date

        self.data.executionInterrupted(date: self.date + 100, retry: true)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 1)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInterruptedOverLimit() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.executionInterrupted(date: self.date + 100, retry: false)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInterruptedExpired() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.schedule.end = self.date

        self.data.executionInterrupted(date: self.date + 100, retry: true)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 1)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testExecutionInterruptedInterval() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing
        self.data.schedule.interval = 10.0
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.executionInterrupted(date: self.date + 100, retry: false)
        XCTAssertEqual(self.data.scheduleState, .paused)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }


    func testFinishedExecuting() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.finishedExecuting(date: self.date + 100)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleState, .idle)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testFinishedExecutingOverLimit() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.finishedExecuting(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testFinishedExecutingExpired() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.schedule.interval = 10.0
        self.data.scheduleState = .executing
        self.data.preparedScheduleInfo = self.preparedScheduleInfo
        self.data.schedule.end = self.date

        self.data.finishedExecuting(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testFinishedExecutingInterval() {
        self.data.schedule.limit = 3
        self.data.executionCount = 1
        self.data.scheduleState = .executing
        self.data.schedule.interval = 10.0
        self.data.preparedScheduleInfo = self.preparedScheduleInfo

        self.data.finishedExecuting(date: self.date + 100)
        XCTAssertEqual(self.data.scheduleState, .paused)
        XCTAssertEqual(self.data.executionCount, 2)
        XCTAssertNil(self.data.preparedScheduleInfo)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testShouldDelete() {
        XCTAssertFalse(self.data.shouldDelete(date: self.date))


        self.data.scheduleState = .finished
        XCTAssertTrue(self.data.shouldDelete(date: self.date))

        self.data.schedule.editGracePeriodDays = 10
        XCTAssertFalse(self.data.shouldDelete(date: self.date))
        XCTAssertFalse(self.data.shouldDelete(date: self.date + 10 * 60 * 60 * 24 - 1))
        XCTAssertTrue(self.data.shouldDelete(date: self.date + 10 * 60 * 60 * 24))
    }

    func testTriggered() {
        let previousTriggerSessionID = self.data.triggerSessionID

        let context = AirshipTriggerContext(type: "some-type", goal: 10.0, event: .string("event"))
        
        self.data.triggered(triggerInfo: TriggeringInfo(context: context, date: self.date), date: self.date + 100)
        XCTAssertEqual(self.data.triggerInfo?.context, context)
        XCTAssertEqual(self.data.triggerInfo?.date, self.date)
        XCTAssertEqual(self.data.scheduleState, .triggered)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
        XCTAssertNotEqual(self.data.triggerSessionID, previousTriggerSessionID)
    }

    func testTriggeredOverLimit() {
        self.data.schedule.limit = 1
        self.data.executionCount = 1

        let context = AirshipTriggerContext(type: "some-type", goal: 10.0, event: .string("event"))
        self.data.triggered(triggerInfo: TriggeringInfo(context: context, date: self.date), date: self.date + 100)

        XCTAssertNil(self.data.triggerInfo)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }

    func testTriggeredExpired() {
        self.data.schedule.limit = 2
        self.data.executionCount = 1
        self.data.schedule.end = self.date

        let context = AirshipTriggerContext(type: "some-type", goal: 10.0, event: .string("event"))
        self.data.triggered(triggerInfo: TriggeringInfo(context: context, date: self.date), date: self.date + 100)

        XCTAssertNil(self.data.triggerInfo)
        XCTAssertEqual(self.data.scheduleState, .finished)
        XCTAssertEqual(self.data.scheduleStateChangeDate, self.date + 100)
    }
}
