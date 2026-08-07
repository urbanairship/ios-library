/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Evaluates whether a schedule has reached its execution limit by counting
/// eligible ledger events, replacing the legacy in-schedule execution counter.
protocol LedgerLimitEvaluatorProtocol: Sendable {
    /// Whether the schedule is at or over its limit.
    ///
    /// Counts `execution` events of every ``LedgerExecutionResult`` (never
    /// `triggered`) recorded under either of the schedule's ledger IDs
    /// (`schedule_id` or its current `shared_id`), minus any events removed by
    /// `limit_config.exclude`, and compares the total against the schedule's
    /// `limit` (nil → 1, 0 → unlimited).
    func isOverLimit(schedule: AutomationSchedule) async -> Bool
}

/// Ledger-backed limit evaluator.
final class LedgerLimitEvaluator: LedgerLimitEvaluatorProtocol {

    private let store: any LedgerStoreProtocol
    private let date: any AirshipDateProtocol

    init(
        store: any LedgerStoreProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.store = store
        self.date = date
    }

    func isOverLimit(schedule: AutomationSchedule) async -> Bool {
        // 0 means no limit; nil means 1.
        let limit = schedule.limit ?? 1
        guard limit != 0 else { return false }

        let events: [LedgerEvent]
        do {
            events = try await self.store.events(
                scheduleID: schedule.identifier,
                sharedID: schedule.ledgerSharedID
            )
        } catch {
            // A ledger read failure must never wedge execution. Err toward
            // showing the message rather than silently suppressing it.
            AirshipLogger.error("Failed to read ledger for limit check \(schedule.identifier): \(error)")
            return false
        }

        return Self.isOverLimit(
            limit: limit,
            events: events,
            context: LedgerLimitContext(
                scheduleID: schedule.identifier,
                currentSharedID: schedule.ledgerSharedID
            ),
            exclude: schedule.limitConfig?.exclude,
            now: self.date.now
        )
    }

    /// Pure limit evaluation over an already-fetched event set. `limit` is the
    /// resolved cap (never nil; caller maps nil → 1 and short-circuits 0).
    static func isOverLimit(
        limit: UInt,
        events: [LedgerEvent],
        context: LedgerLimitContext,
        exclude: ExclusionSet?,
        now: Date
    ) -> Bool {
        var total = 0
        for event in events {
            // Only executions count toward the limit; triggered events never do.
            guard case .execution(let execution) = event else { continue }

            if let exclude, exclude.excludes(event, context: context, now: now) {
                continue
            }

            total += execution.count ?? 1
            if total >= limit { return true }
        }

        return total >= limit
    }
}
