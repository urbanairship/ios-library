/* Copyright Airship and Contributors */

import Foundation

/// Serializes executions that share a ledger group.
///
/// Schedules that pool a budget through `ledger_config.shared_ids` are limited by
/// counting `execution` events, but those events are only written once an
/// execution finishes — a message records nothing while it is still on screen.
/// Between the limit check and that write, a sibling in the same group reads a
/// stale tally and displays too.
///
/// A reservation covers exactly that window: one in-flight execution per group,
/// so the next one only proceeds once the previous has recorded and the ledger
/// can answer honestly. Waiting rather than skipping matters — the holder may
/// still fail without spending the budget, and then the waiter should run.
///
/// In-process only, and deliberately not persisted: it guards concurrent
/// execution on a single device, which is the whole of the gap. Anything that
/// outlives the process is already covered by the ledger.
actor LedgerGroupReservations {

    private var reserved: Set<String> = []
    private var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]

    /// Reserves every group in `sharedIDs`, suspending until each is free.
    ///
    /// A schedule can belong to several groups at once, and every one of them
    /// has to be held for the execution — a sibling in any single shared group
    /// would otherwise read a stale tally. The groups are taken one at a time
    /// in sorted order, and that order is the whole of the deadlock argument:
    /// two schedules overlapping on `[a, b]` both take `a` before `b`, so the
    /// one that loses the race for `a` never sits on `b` while waiting for it.
    /// Sorting here rather than trusting callers keeps the guarantee local —
    /// ``LedgerSharedIDs/canonical(_:)`` already sorts, so this is normally a
    /// no-op.
    func reserve(_ sharedIDs: [String]) async {
        // Deduplicated, not just sorted: a repeated ID within one call would
        // otherwise try to reserve a group this same call already holds,
        // parking forever on a release only this call could ever issue.
        for sharedID in Set(sharedIDs).sorted() {
            await self.reserve(single: sharedID)
        }
    }

    /// Releases every group in `sharedIDs`, each to whatever has waited longest.
    ///
    /// Released in reverse acquisition order, mirroring the nesting. Order does
    /// not affect correctness here: each group is handed over independently and
    /// a woken waiter resumes on the actor, so no waiter can observe a
    /// half-released set.
    func release(_ sharedIDs: [String]) {
        // Deduplicated to match `reserve`'s acquisition count: `reserve` takes
        // each distinct ID exactly once, so a repeated ID here would release
        // that same group twice — the second call finding no waiter and
        // clearing `reserved` out from under whoever the first call just
        // handed it to, letting an unrelated caller acquire a group that is
        // still legitimately held.
        for sharedID in Set(sharedIDs).sorted().reversed() {
            self.release(single: sharedID)
        }
    }

    /// Reserves one group, suspending until any current holder releases.
    private func reserve(single sharedID: String) async {
        guard reserved.contains(sharedID) else {
            reserved.insert(sharedID)
            return
        }

        // Parked in arrival order. `release` hands the reservation over rather
        // than dropping it, so being resumed *is* holding it — there is nothing
        // to re-test on wake.
        await withCheckedContinuation { continuation in
            waiting[sharedID, default: []].append(continuation)
        }
    }

    /// Releases one reservation, passing the group to whatever has waited
    /// longest.
    ///
    /// The reservation is handed to the head of the queue instead of being
    /// cleared and re-taken: clearing it lets a caller that arrives before the
    /// woken waiter gets back onto the actor take the group instead, and since a
    /// reservation is held for a whole display, a repeatedly-barged waiter is one
    /// that never shows.
    private func release(single sharedID: String) {
        guard var queue = waiting[sharedID], !queue.isEmpty else {
            reserved.remove(sharedID)
            waiting.removeValue(forKey: sharedID)
            return
        }

        let next = queue.removeFirst()
        if queue.isEmpty {
            waiting.removeValue(forKey: sharedID)
        } else {
            waiting[sharedID] = queue
        }

        // `reserved` deliberately stays set — it now belongs to `next`.
        next.resume()
    }

    /// Whether the group currently has an execution in flight. Test-only.
    func isReserved(_ sharedID: String) -> Bool {
        reserved.contains(sharedID)
    }

    /// How many executions are parked on the group. Test-only.
    func waitingCount(_ sharedID: String) -> Int {
        waiting[sharedID]?.count ?? 0
    }
}
