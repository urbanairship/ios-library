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

/// One in-flight execution per pooled group, so a sibling cannot read the tally
/// while the holder is still displaying and has not recorded yet.
struct LedgerGroupReservationsTest {

    /// Polls until `condition` holds. Used to park a waiter before starting the
    /// next one, so tests can pin down arrival order instead of guessing at it.
    private static func waitUntil(
        _ condition: @Sendable () async -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Condition was never met", sourceLocation: sourceLocation)
    }

    @Test
    func testReserveThenReleaseFreesTheGroup() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.reserve("group")
        #expect(await reservations.isReserved("group"))

        await reservations.release("group")
        #expect(!(await reservations.isReserved("group")))
    }

    @Test
    func testDifferentGroupsDoNotBlockEachOther() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.reserve("a")
        // Would hang if groups shared a single slot.
        await reservations.reserve("b")

        #expect(await reservations.isReserved("a"))
        #expect(await reservations.isReserved("b"))
    }

    @Test
    func testSecondReserveWaitsUntilTheFirstReleases() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve("group")

        let acquired = AirshipAtomicValue(false)
        let waiter = Task {
            await reservations.reserve("group")
            acquired.set(true)
        }

        // Give the waiter a chance to run; it must still be blocked.
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(!acquired.value)

        await reservations.release("group")
        await waiter.value
        #expect(acquired.value)
    }

    /// A release hands the group to one waiter, so a queue drains one execution
    /// per release rather than all at once.
    @Test
    func testOnlyOneOfManyWaitersProceedsPerRelease() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve("group")

        let acquired = AirshipAtomicValue(0)
        let waiters = (0..<3).map { _ in
            Task {
                await reservations.reserve("group")
                acquired.update { $0 += 1 }
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(acquired.value == 0)

        // Each release lets exactly one more through.
        for expected in 1...3 {
            await reservations.release("group")
            var observed = 0
            for _ in 0..<50 {
                observed = acquired.value
                if observed >= expected { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            #expect(observed == expected)
        }

        for waiter in waiters { await waiter.value }
        await reservations.release("group")
        #expect(!(await reservations.isReserved("group")))
    }

    /// Parks each waiter before starting the next, so arrival order is known,
    /// then checks they are served in it. A reservation is held for a whole
    /// display, so a waiter that keeps losing is a message that never shows.
    @Test
    func testWaitersAreServedInArrivalOrder() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve("group")

        let order = AirshipAtomicValue<[Int]>([])
        var waiters: [Task<Void, Never>] = []
        for index in 0..<3 {
            waiters.append(
                Task {
                    await reservations.reserve("group")
                    order.update { $0.append(index) }
                }
            )
            try await Self.waitUntil { await reservations.waitingCount("group") == index + 1 }
        }

        for expected in 1...3 {
            await reservations.release("group")
            try await Self.waitUntil { order.value.count == expected }
        }

        for waiter in waiters { await waiter.value }
        #expect(order.value == [0, 1, 2])

        await reservations.release("group")
        #expect(!(await reservations.isReserved("group")))
    }

    /// The group is never momentarily free while something is waiting on it: the
    /// reservation transfers directly, so a caller arriving during the handoff
    /// queues behind the waiter instead of jumping it.
    @Test
    func testGroupIsNeverFreeWhileAWaiterIsQueued() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve("group")

        let acquired = AirshipAtomicValue(false)
        let waiter = Task {
            await reservations.reserve("group")
            acquired.set(true)
        }
        try await Self.waitUntil { await reservations.waitingCount("group") == 1 }

        await reservations.release("group")
        #expect(await reservations.isReserved("group"))

        // A newcomer racing the handoff finds the group taken and queues.
        let newcomerAcquired = AirshipAtomicValue(false)
        let newcomer = Task {
            await reservations.reserve("group")
            newcomerAcquired.set(true)
        }

        await waiter.value
        #expect(acquired.value)
        #expect(!newcomerAcquired.value)

        await reservations.release("group")
        await newcomer.value
        #expect(newcomerAcquired.value)
    }

    @Test
    func testReleasingAnUnheldGroupIsANoOp() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.release("never-held")
        await reservations.release("never-held")

        #expect(!(await reservations.isReserved("never-held")))
        // Still usable afterwards.
        await reservations.reserve("never-held")
        #expect(await reservations.isReserved("never-held"))
    }
}
