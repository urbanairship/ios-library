/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Records ledger events from the live execution pipeline.
///
/// This is the write-side counterpart to ``LedgerStoreProtocol``: it turns the
/// coarse execution outcomes observed by the engine, preparer, and executors
/// into ``LedgerEvent``s and appends them to the store. Recording failures are
/// logged and swallowed — a ledger write must never break execution.
protocol AutomationLedgerProtocol: Sendable {

    /// Records a `triggered` event: an execution-causing trigger reached its
    /// goal.
    func recordTriggered(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?
    ) async

    /// Records the single outcome `execution` event for an attempt.
    /// - Parameters:
    ///   - result: How the execution resolved.
    ///   - cancel: True if this outcome also cancelled the schedule.
    func recordExecution(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?,
        result: LedgerExecutionResult,
        cancel: Bool
    ) async
}

/// Ledger recorder backed by a ``LedgerStoreProtocol``.
final class AutomationLedger: AutomationLedgerProtocol {

    private let store: any LedgerStoreProtocol
    private let date: any AirshipDateProtocol

    init(
        store: any LedgerStoreProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.store = store
        self.date = date
    }

    func recordTriggered(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?
    ) async {
        await self.record(
            .triggered(
                .init(
                    scheduleID: scheduleID,
                    sharedID: sharedID,
                    triggerID: triggerID,
                    timestamp: self.date.now,
                    count: nil
                )
            )
        )
    }

    func recordExecution(
        scheduleID: String,
        sharedID: String?,
        triggerID: String?,
        result: LedgerExecutionResult,
        cancel: Bool
    ) async {
        await self.record(
            .execution(
                .init(
                    scheduleID: scheduleID,
                    sharedID: sharedID,
                    triggerID: triggerID,
                    timestamp: self.date.now,
                    count: nil,
                    result: result,
                    cancel: cancel
                )
            )
        )
    }

    private func record(_ event: LedgerEvent) async {
        do {
            try await self.store.recordEvents([event])
        } catch {
            AirshipLogger.error("Failed to record ledger event \(event): \(error)")
        }
    }
}
