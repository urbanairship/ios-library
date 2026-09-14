/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Evaluates whether a schedule has reached its execution limit by counting
/// eligible ledger events, replacing the legacy in-schedule execution counter.
protocol LedgerLimitEvaluatorProtocol: Sendable {
    /// Whether the schedule is at or over its limit.
    ///
    /// Counts this schedule's own `execution` events (every
    /// ``LedgerExecutionResult``, never `triggered`), plus — only when
    /// `limit_config.type` is `"shared"` — events whose `schedule_id` or
    /// `shared_id` matches its current `shared_id` too (the `schedule_id` half
    /// is what lets it inherit a named schedule's pre-existing history, even
    /// history recorded before that schedule ever had a `shared_id` at all —
    /// see ``LedgerStoreProtocol/events(scheduleID:sharedID:)``), minus any
    /// events removed by `limit_config.exclude`, and compares the total
    /// against the schedule's `limit` (nil → 1, 0 → unlimited).
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

        let limitConfig = schedule.limitConfig ?? .selfOnly(exclude: nil)

        // Only look beyond this schedule's own events when it has explicitly
        // opted in — its own payload alone must determine this, independent of
        // what any other schedule declares as its shared_id.
        let sharedID: String?
        switch limitConfig {
        case .selfOnly, .unknown:
            sharedID = nil
        case .shared:
            sharedID = schedule.ledgerSharedID
        }

        let events: [LedgerEvent]
        do {
            events = try await self.store.events(
                scheduleID: schedule.identifier,
                sharedID: sharedID
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
            limitConfig: limitConfig,
            now: self.date.now
        )
    }

    /// Pure limit evaluation over an already-fetched event set. `limit` is the
    /// resolved cap (never nil; caller maps nil → 1 and short-circuits 0).
    static func isOverLimit(
        limit: UInt,
        events: [LedgerEvent],
        context: LedgerLimitContext,
        limitConfig: LimitConfig,
        now: Date
    ) -> Bool {
        var total = 0
        for event in events {
            // Only executions count toward the limit; triggered events never do.
            guard case .execution(let execution) = event else { continue }

            let excluder: (any Excluder)?
            switch limitConfig {
            case .selfOnly(let exclude): excluder = exclude
            case .shared(let exclude): excluder = exclude
            case .unknown: excluder = nil
            }
            if excluder?.excludes(event, context: context, now: now) ?? false { continue }

            total += execution.count ?? 1
            if total >= limit { return true }
        }

        return total >= limit
    }
}
