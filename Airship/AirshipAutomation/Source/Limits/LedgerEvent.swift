/* Copyright Airship and Contributors */

import Foundation

/// Coarse event types tracked by the ledger. Every schedule records events
/// automatically: `triggered` when an execution-causing trigger reaches its
/// goal, and `execution` when that attempt resolves to a budget-consuming
/// outcome.
///
/// This axis is deliberately coarse so counting stays forward-compatible: a
/// limit counts `execution` events regardless of their ``LedgerExecutionResult``.
enum LedgerEventType: String, Sendable, Codable, Equatable, CaseIterable {
    case triggered
    case execution
}

/// How an `execution` event resolved. This is the fine axis: it never affects
/// whether an execution is counted, only which executions an exclusion rule
/// can subtract.
enum LedgerExecutionResult: String, Sendable, Codable, Equatable, CaseIterable {
    /// The schedule did its thing: the scene was displayed or the actions ran.
    case succeeded

    /// A holdout group execution: everything except display or actions
    /// occurred. Counts toward the limit like a real execution.
    case holdout

    /// A variant control: the user triggered the experiment but was assigned a
    /// different variant. Not a holdout.
    case control

    /// The audience check failed with a budget-consuming miss behavior.
    case audienceMiss = "audience_miss"

    /// Synthesized from a pre-ledger execution count during migration.
    case backfill
}

/// The scope an event was recorded under. An event is always recorded under
/// its schedule's ID, and additionally under a shared group ID when the
/// recording schedule had a `ledger_config.shared_id` at record time.
enum LedgerScope: Sendable, Equatable, Hashable {
    /// Events recorded by a specific schedule (matched on `scheduleID`).
    case schedule(String)

    /// Events recorded under a specific shared group (matched on `sharedID`).
    case shared(String)
}

/// A single event recorded by the ledger.
///
/// Every event carries the scope it was recorded under: `scheduleID` always,
/// and `sharedID` (the `ledger_config.shared_id` active at record time) when
/// the recording schedule had one. Neither ID is ever rewritten, so an event
/// stays with the scopes it was recorded under even after the schedule changes
/// its config.
///
/// An event is eligible for a schedule's limit evaluation when either scope ID
/// matches one of the schedule's ledger IDs: its `scheduleID` equals the
/// schedule's own ID, or its `sharedID` equals the schedule's current shared
/// ledger ID.
enum LedgerEvent: Sendable, Equatable, Hashable {

    /// Recorded when an execution-causing trigger reaches its goal.
    case triggered(Triggered)

    /// Recorded when an attempt resolves to a budget-consuming outcome.
    case execution(Execution)

    /// Payload for a `triggered` event.
    struct Triggered: Sendable, Equatable, Hashable, Codable {
        /// ID of the schedule that recorded the event.
        var scheduleID: String

        /// Shared group ID the recording schedule had at record time, if any.
        var sharedID: String?

        /// ID of the execution-causing trigger, if known. A plain attribute
        /// for matching and reporting only; never a recording scope key.
        var triggerID: String?

        /// When the event was recorded.
        var timestamp: Date

        /// Number of occurrences this event represents. If nil, 1.
        var count: Int?
    }

    /// Payload for an `execution` event.
    struct Execution: Sendable, Equatable, Hashable, Codable {
        /// ID of the schedule that recorded the event.
        var scheduleID: String

        /// Shared group ID the recording schedule had at record time, if any.
        /// Always nil for `backfill`, so legacy history never pollutes a
        /// group's pooled tally.
        var sharedID: String?

        /// ID of the execution-causing trigger, if known. A plain attribute
        /// for matching and reporting only; never a recording scope key.
        var triggerID: String?

        /// When the event was recorded.
        var timestamp: Date

        /// Number of occurrences this event represents. If nil, 1.
        var count: Int?

        /// How the execution resolved.
        var result: LedgerExecutionResult

        /// True if this outcome also cancelled the schedule. If nil, false.
        var cancel: Bool?
    }
}

extension LedgerEvent {

    /// The coarse type of the event.
    var type: LedgerEventType {
        switch self {
        case .triggered: return .triggered
        case .execution: return .execution
        }
    }

    /// ID of the schedule that recorded the event.
    var scheduleID: String {
        switch self {
        case .triggered(let event): return event.scheduleID
        case .execution(let event): return event.scheduleID
        }
    }

    /// Shared group ID the recording schedule had at record time, if any.
    var sharedID: String? {
        switch self {
        case .triggered(let event): return event.sharedID
        case .execution(let event): return event.sharedID
        }
    }

    /// ID of the execution-causing trigger, if known.
    var triggerID: String? {
        switch self {
        case .triggered(let event): return event.triggerID
        case .execution(let event): return event.triggerID
        }
    }

    /// When the event was recorded.
    var timestamp: Date {
        switch self {
        case .triggered(let event): return event.timestamp
        case .execution(let event): return event.timestamp
        }
    }

    /// Number of occurrences this event represents. Defaults to 1.
    var count: Int {
        let raw: Int? = switch self {
        case .triggered(let event): event.count
        case .execution(let event): event.count
        }
        return raw ?? 1
    }

    /// The scopes this event was recorded under: always its schedule, plus its
    /// shared group when present.
    var scopes: [LedgerScope] {
        var result: [LedgerScope] = [.schedule(scheduleID)]
        if let sharedID {
            result.append(.shared(sharedID))
        }
        return result
    }
}

extension LedgerEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(LedgerEventType.self, forKey: .type)
        switch type {
        case .triggered:
            self = .triggered(try Triggered(from: decoder))
        case .execution:
            self = .execution(try Execution(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case .triggered(let event): try event.encode(to: encoder)
        case .execution(let event): try event.encode(to: encoder)
        }
    }
}

extension LedgerEvent.Triggered {
    private enum CodingKeys: String, CodingKey {
        case scheduleID = "schedule_id"
        case sharedID = "shared_id"
        case triggerID = "trigger_id"
        case timestamp
        case count
    }
}

extension LedgerEvent.Execution {
    private enum CodingKeys: String, CodingKey {
        case scheduleID = "schedule_id"
        case sharedID = "shared_id"
        case triggerID = "trigger_id"
        case timestamp
        case count
        case result
        case cancel
    }
}
