/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

/// Spy ``AutomationLedgerProtocol`` used across executor/preparer/engine tests
/// to assert exactly which ledger events a code path records.
actor TestAutomationLedger: AutomationLedgerProtocol {

    enum Recorded: Equatable, Sendable {
        case triggered(
            scheduleID: String,
            sharedIDs: [String],
            triggerID: String?,
            variantAudienceID: String?
        )
        case execution(
            scheduleID: String,
            sharedIDs: [String],
            triggerID: String?,
            variantAudienceID: String?,
            result: LedgerExecutionResult,
            cancel: Bool
        )
    }

    private(set) var recorded: [Recorded] = []

    func recordTriggered(
        scheduleID: String,
        sharedIDs: [String],
        triggerID: String?,
        variantAudienceID: String?
    ) async {
        self.recorded.append(
            .triggered(
                scheduleID: scheduleID,
                sharedIDs: sharedIDs,
                triggerID: triggerID,
                variantAudienceID: variantAudienceID
            )
        )
    }

    func recordExecution(
        scheduleID: String,
        sharedIDs: [String],
        triggerID: String?,
        variantAudienceID: String?,
        result: LedgerExecutionResult,
        cancel: Bool
    ) async {
        self.recorded.append(
            .execution(
                scheduleID: scheduleID,
                sharedIDs: sharedIDs,
                triggerID: triggerID,
                variantAudienceID: variantAudienceID,
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
        sharedIDs: [String],
        triggerID: String?,
        variantAudienceID: String?
    ) async {}

    func recordExecution(
        scheduleID: String,
        sharedIDs: [String],
        triggerID: String?,
        variantAudienceID: String?,
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
            sharedIDs: ["group-1"],
            triggerID: "trigger-1",
            variantAudienceID: nil
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        #expect(events == [
            .triggered(
                .init(
                    scheduleID: "schedule-1",
                    sharedIDs: ["group-1"],
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
            sharedIDs: [],
            triggerID: nil,
            variantAudienceID: nil,
            result: .succeeded,
            cancel: false
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(events == [
            .execution(
                .init(
                    scheduleID: "schedule-1",
                    sharedIDs: nil,
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
    func testRecordStampsVariantAudienceID() async throws {
        let ledger = AutomationLedger(store: store, date: date)

        await ledger.recordTriggered(
            scheduleID: "schedule-1",
            sharedIDs: [],
            triggerID: nil,
            variantAudienceID: "iteration-1"
        )
        await ledger.recordExecution(
            scheduleID: "schedule-1",
            sharedIDs: [],
            triggerID: nil,
            variantAudienceID: "iteration-1",
            result: .variantMiss,
            cancel: false
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedIDs: [])
        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.variantAudienceID == "iteration-1" })
        // A plain attribute: never a scope the event is also recorded under.
        #expect(try await store.events(scheduleID: "other", sharedIDs: ["iteration-1"]).isEmpty)
    }

    @Test
    func testRecordExecutionCancelStampsFlag() async throws {
        let ledger = AutomationLedger(store: store, date: date)

        await ledger.recordExecution(
            scheduleID: "schedule-1",
            sharedIDs: ["group-1"],
            triggerID: "trigger-1",
            variantAudienceID: nil,
            result: .audienceMiss,
            cancel: true
        )

        let events = try await store.events(scheduleID: "schedule-1", sharedIDs: ["group-1"])
        #expect(events == [
            .execution(
                .init(
                    scheduleID: "schedule-1",
                    sharedIDs: ["group-1"],
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

        await reservations.reserve(["group"])
        #expect(await reservations.isReserved("group"))

        await reservations.release(["group"])
        #expect(!(await reservations.isReserved("group")))
    }

    @Test
    func testDifferentGroupsDoNotBlockEachOther() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.reserve(["a"])
        // Would hang if groups shared a single slot.
        await reservations.reserve(["b"])

        #expect(await reservations.isReserved("a"))
        #expect(await reservations.isReserved("b"))
    }

    /// `reserve` sorts its input but must also de-duplicate it: a repeated ID
    /// within one call would otherwise try to take a group the same call
    /// already holds, parking forever on a release only that call could ever
    /// issue. Not reachable through `AutomationSchedule.ledgerSharedIDs`, which
    /// is always canonical — this pins the actor's own behavior directly so a
    /// future caller that isn't canonical doesn't wedge a group permanently.
    @Test
    func testDuplicateIDWithinOneReserveCallDoesNotDeadlock() async throws {
        let reservations = LedgerGroupReservations()

        // Would hang forever before the fix.
        await reservations.reserve(["a", "a"])

        #expect(await reservations.isReserved("a"))
        #expect(await reservations.waitingCount("a") == 0)

        await reservations.release(["a", "a"])
        #expect(!(await reservations.isReserved("a")))
    }

    /// The failure mode `release`'s own dedup guards against: without it, a
    /// duplicate-containing release fires twice for one real acquisition — the
    /// first hands the group to a legitimate waiter, and the un-deduplicated
    /// second call finds no one waiting and clears `reserved` anyway, letting
    /// an unrelated third caller acquire a group someone else still holds.
    @Test
    func testDuplicateIDWithinOneReleaseCallDoesNotStealFromTheNewHolder() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.reserve(["a", "a"])

        let task2Acquired = AirshipAtomicValue(false)
        let task2 = Task {
            await reservations.reserve(["a"])
            task2Acquired.set(true)
        }
        for _ in 0..<200 {
            if await reservations.waitingCount("a") == 1 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(await reservations.waitingCount("a") == 1)

        // Releasing with the same duplicate array the reservation was taken
        // with must not also clear the group out from under task 2.
        await reservations.release(["a", "a"])

        for _ in 0..<200 {
            if task2Acquired.value { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(task2Acquired.value)
        #expect(await reservations.isReserved("a"))

        // An unrelated third caller must still be blocked.
        let task3Acquired = AirshipAtomicValue(false)
        let task3 = Task {
            await reservations.reserve(["a"])
            task3Acquired.set(true)
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
        #expect(!task3Acquired.value)

        await reservations.release(["a"])
        await task3.value
        await reservations.release(["a"])
        _ = task2
    }

    @Test
    func testSecondReserveWaitsUntilTheFirstReleases() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve(["group"])

        let acquired = AirshipAtomicValue(false)
        let waiter = Task {
            await reservations.reserve(["group"])
            acquired.set(true)
        }

        // Give the waiter a chance to run; it must still be blocked.
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(!acquired.value)

        await reservations.release(["group"])
        await waiter.value
        #expect(acquired.value)
    }

    /// A release hands the group to one waiter, so a queue drains one execution
    /// per release rather than all at once.
    @Test
    func testOnlyOneOfManyWaitersProceedsPerRelease() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve(["group"])

        let acquired = AirshipAtomicValue(0)
        let waiters = (0..<3).map { _ in
            Task {
                await reservations.reserve(["group"])
                acquired.update { $0 += 1 }
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(acquired.value == 0)

        // Each release lets exactly one more through.
        for expected in 1...3 {
            await reservations.release(["group"])
            var observed = 0
            for _ in 0..<50 {
                observed = acquired.value
                if observed >= expected { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            #expect(observed == expected)
        }

        for waiter in waiters { await waiter.value }
        await reservations.release(["group"])
        #expect(!(await reservations.isReserved("group")))
    }

    /// Parks each waiter before starting the next, so arrival order is known,
    /// then checks they are served in it. A reservation is held for a whole
    /// display, so a waiter that keeps losing is a message that never shows.
    @Test
    func testWaitersAreServedInArrivalOrder() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve(["group"])

        let order = AirshipAtomicValue<[Int]>([])
        var waiters: [Task<Void, Never>] = []
        for index in 0..<3 {
            waiters.append(
                Task {
                    await reservations.reserve(["group"])
                    order.update { $0.append(index) }
                }
            )
            try await Self.waitUntil { await reservations.waitingCount("group") == index + 1 }
        }

        for expected in 1...3 {
            await reservations.release(["group"])
            try await Self.waitUntil { order.value.count == expected }
        }

        for waiter in waiters { await waiter.value }
        #expect(order.value == [0, 1, 2])

        await reservations.release(["group"])
        #expect(!(await reservations.isReserved("group")))
    }

    /// The group is never momentarily free while something is waiting on it: the
    /// reservation transfers directly, so a caller arriving during the handoff
    /// queues behind the waiter instead of jumping it.
    @Test
    func testGroupIsNeverFreeWhileAWaiterIsQueued() async throws {
        let reservations = LedgerGroupReservations()
        await reservations.reserve(["group"])

        let acquired = AirshipAtomicValue(false)
        let waiter = Task {
            await reservations.reserve(["group"])
            acquired.set(true)
        }
        try await Self.waitUntil { await reservations.waitingCount("group") == 1 }

        await reservations.release(["group"])
        #expect(await reservations.isReserved("group"))

        // A newcomer racing the handoff finds the group taken and queues.
        let newcomerAcquired = AirshipAtomicValue(false)
        let newcomer = Task {
            await reservations.reserve(["group"])
            newcomerAcquired.set(true)
        }

        await waiter.value
        #expect(acquired.value)
        #expect(!newcomerAcquired.value)

        await reservations.release(["group"])
        await newcomer.value
        #expect(newcomerAcquired.value)
    }

    @Test
    func testReleasingAnUnheldGroupIsANoOp() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.release(["never-held"])
        await reservations.release(["never-held"])

        #expect(!(await reservations.isReserved("never-held")))
        // Still usable afterwards.
        await reservations.reserve(["never-held"])
        #expect(await reservations.isReserved("never-held"))
    }

    // MARK: - Multiple groups per execution

    @Test
    func testReserveHoldsEveryGroupInTheSet() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.reserve(["a", "b"])

        #expect(await reservations.isReserved("a"))
        #expect(await reservations.isReserved("b"))

        await reservations.release(["a", "b"])

        #expect(!(await reservations.isReserved("a")))
        #expect(!(await reservations.isReserved("b")))
    }

    @Test
    func testOverlappingSetsSerialize() async throws {
        let reservations = LedgerGroupReservations()

        // Holds `shared`; a schedule in `[group-b, shared]` overlaps on it.
        await reservations.reserve(["group-a", "shared"])

        let acquired = AirshipAtomicValue(false)
        let waiter = Task {
            await reservations.reserve(["group-b", "shared"])
            acquired.set(true)
        }

        try await Self.waitUntil { await reservations.waitingCount("shared") == 1 }
        #expect(!acquired.value)

        await reservations.release(["group-a", "shared"])
        await waiter.value
        #expect(acquired.value)
    }

    @Test
    func testDisjointSetsDoNotBlockEachOther() async throws {
        let reservations = LedgerGroupReservations()

        await reservations.reserve(["a", "b"])
        // Would hang if any group were shared between the two sets.
        await reservations.reserve(["c", "d"])

        #expect(await reservations.isReserved("c"))
        #expect(await reservations.isReserved("d"))
    }

    @Test
    func testOppositeOrderInputsDoNotDeadlock() async throws {
        let reservations = LedgerGroupReservations()

        // Two schedules over the same pair, handed to `reserve` in opposite
        // orders. Sorted acquisition is what keeps one from holding `b` while
        // waiting on `a` as the other does the reverse — without it these two
        // can wedge against each other forever.
        await reservations.reserve(["a", "b"])

        let acquired = AirshipAtomicValue(false)
        let waiter = Task {
            await reservations.reserve(["b", "a"])
            acquired.set(true)
        }

        // Blocked on the lower of the two, never holding the higher one.
        try await Self.waitUntil { await reservations.waitingCount("a") == 1 }
        #expect(await reservations.waitingCount("b") == 0)
        #expect(!acquired.value)

        await reservations.release(["b", "a"])
        await waiter.value
        #expect(acquired.value)
    }
}
