/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

/// Spy ``AutomationLedgerProtocol`` used across executor/preparer/engine tests
/// to assert exactly which ledger events a code path records.
actor TestAutomationLedger: AutomationLedgerProtocol {

    enum Recorded: Equatable, Sendable {
        case triggered(scheduleID: String, sharedID: String?, triggerID: String?)
        case execution(
            scheduleID: String,
            sharedID: String?,
            triggerID: String?,
            result: LedgerExecutionResult,
            cancel: Bool
        )
    }

    private(set) var recorded: [Recorded] = []

    func recordTriggered(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?
    ) async {
        self.recorded.append(
            .triggered(scheduleID: scheduleID, sharedID: sharedID, triggerID: triggerID)
        )
    }

    func recordExecution(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?,
        result: LedgerExecutionResult,
        cancel: Bool
    ) async {
        self.recorded.append(
            .execution(
                scheduleID: scheduleID,
                sharedID: sharedID,
                triggerID: triggerID,
                result: result,
                cancel: cancel
            )
        )
    }
}

/// Inert ledger for tests that construct a component but don't exercise ledger
/// recording. Lets those call sites satisfy the required `ledger` dependency
/// without asserting on it.
struct NoOpAutomationLedger: AutomationLedgerProtocol {
    func recordTriggered(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?
    ) async {}

    func recordExecution(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?,
        result: LedgerExecutionResult,
        cancel: Bool
    ) async {}
}

struct AutomationLedgerTest {

    private let store = LedgerStore(appKey: UUID().uuidString, inMemory: true)
    private let date = UATestDate(offset: 0, dateOverride: Date(timeIntervalSince1970: 1000))

    @Test
    func testRecordTriggered() async throws {
        let ledger = AutomationLedger(store: store, date: date)

        await ledger.recordTriggered(
            scheduleID: "schedule-1",
            sharedID: "group-1",
            triggerID: "trigger-1"
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedID: "group-1")
        #expect(events == [
            .triggered(
                .init(
                    scheduleID: "schedule-1",
                    sharedID: "group-1",
                    triggerID: "trigger-1",
                    timestamp: Date(timeIntervalSince1970: 1000),
                    count: nil
                )
            )
        ])
    }

    @Test
    func testRecordExecutionSucceeded() async throws {
        let ledger = AutomationLedger(store: store, date: date)

        await ledger.recordExecution(
            scheduleID: "schedule-1",
            sharedID: nil,
            triggerID: nil,
            result: .succeeded,
            cancel: false
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedID: nil)
        #expect(events == [
            .execution(
                .init(
                    scheduleID: "schedule-1",
                    sharedID: nil,
                    triggerID: nil,
                    timestamp: Date(timeIntervalSince1970: 1000),
                    count: nil,
                    result: .succeeded,
                    cancel: false
                )
            )
        ])
    }

    @Test
    func testRecordExecutionCancelStampsFlag() async throws {
        let ledger = AutomationLedger(store: store, date: date)

        await ledger.recordExecution(
            scheduleID: "schedule-1",
            sharedID: "group-1",
            triggerID: "trigger-1",
            result: .audienceMiss,
            cancel: true
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedID: "group-1")
        #expect(events == [
            .execution(
                .init(
                    scheduleID: "schedule-1",
                    sharedID: "group-1",
                    triggerID: "trigger-1",
                    timestamp: Date(timeIntervalSince1970: 1000),
                    count: nil,
                    result: .audienceMiss,
                    cancel: true
                )
            )
        ])
    }
}
