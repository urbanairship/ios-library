/* Copyright Airship and Contributors */

import Foundation

/// Serializes executions that share a ledger group.
///
/// Schedules that pool a budget through `ledger_config.shared_id` are limited by
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

    /// Reserves `sharedID`, suspending until any current holder releases.
    func reserve(_ sharedID: String) async {
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

    /// Releases a reservation, passing the group to whatever has waited longest.
    ///
    /// The reservation is handed to the head of the queue instead of being
    /// cleared and re-taken: clearing it lets a caller that arrives before the
    /// woken waiter gets back onto the actor take the group instead, and since a
    /// reservation is held for a whole display, a repeatedly-barged waiter is one
    /// that never shows.
    func release(_ sharedID: String) {
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
