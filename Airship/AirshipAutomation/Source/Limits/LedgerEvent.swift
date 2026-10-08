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

    /// The user reached the last mile before display — trigger fired,
    /// audience and frequency checks passed, assets loaded — but the
    /// resolved outcome was "no message." Everything except display or
    /// actions occurred, so it counts toward the limit like a real
    /// execution. Emitted by the global holdout mechanism (holdout
    /// experiment groups / `bypass_holdout_groups`), and equally by a
    /// variant experiment whose resolved bucket lands in its own no-message
    /// arm — the two are indistinguishable in their effect on the ledger,
    /// only in why they occurred.
    case holdout

    /// The user reached the same last mile as `holdout`, but the resolved
    /// bucket belongs to a sibling schedule's arm in the same variant
    /// experiment. Not a holdout: the user wasn't assigned "no message,"
    /// just not this schedule's message. Counts toward the limit by
    /// default, same as any other execution.
    case variantMiss = "variant_miss"

    /// The audience check failed with a budget-consuming miss behavior.
    case audienceMiss = "audience_miss"

    /// Synthesized from a pre-ledger execution count during migration.
    case backfill

    /// The app was torn down while the message was still displaying, so
    /// nothing else will ever resolve the attempt. Counts toward the limit
    /// like `succeeded` - the alternative is an attempt the ledger never
    /// learns about, which never stops the schedule from re-triggering.
    case interrupted
}

/// The scope an event was recorded under. An event is always recorded under
/// its schedule's ID, and additionally under every shared group ID the
/// recording schedule had in `ledger_config.shared_ids` at record time.
enum LedgerScope: Sendable, Equatable, Hashable {
    /// Events recorded by a specific schedule (matched on `scheduleID`).
    case schedule(String)

    /// Events recorded under a specific shared group (matched against the
    /// event's `sharedIDs`).
    case shared(String)
}

/// Canonicalization for the shared group IDs carried by a config or an event.
///
/// A schedule's `ledger_config.shared_ids` is an unordered set in intent but
/// arrives as a JSON array, so it is reduced to one canonical form — empties
/// dropped, duplicates removed, sorted — before it is stamped onto an event or
/// used for matching. Canonical form matters beyond tidiness: it makes two
/// events that belong to the same groups compare and hash equal, which is what
/// lets ``LedgerCompactor`` merge them, and it gives every caller of
/// ``LedgerGroupReservations`` the same lock ordering.
enum LedgerSharedIDs {

    /// The canonical form of `ids`: non-empty, de-duplicated, sorted. Empty
    /// when there are no usable IDs.
    static func canonical(_ ids: [String]?) -> [String] {
        guard let ids, !ids.isEmpty else { return [] }
        return Set(ids.filter { !$0.isEmpty }).sorted()
    }

    /// The canonical form of `ids`, or nil when empty — for optional payload
    /// fields that should be omitted from JSON rather than encoded as `[]`.
    static func canonicalOrNil(_ ids: [String]?) -> [String]? {
        let canonical = self.canonical(ids)
        return canonical.isEmpty ? nil : canonical
    }
}

/// A single event recorded by the ledger.
///
/// Every event carries the scopes it was recorded under: `scheduleID` always,
/// and `sharedIDs` (the `ledger_config.shared_ids` active at record time) when
/// the recording schedule had any. No ID is ever rewritten, so an event stays
/// with the scopes it was recorded under even after the schedule changes its
/// config.
///
/// An event is eligible for a schedule's limit evaluation when any scope ID
/// matches one of the schedule's ledger IDs: its `scheduleID` equals the
/// schedule's own ID, or its `sharedIDs` intersect the schedule's current
/// shared ledger IDs.
enum LedgerEvent: Sendable, Equatable, Hashable {

    /// Recorded when an execution-causing trigger reaches its goal.
    case triggered(Triggered)

    /// Recorded when an attempt resolves to a budget-consuming outcome.
    case execution(Execution)

    /// Payload for a `triggered` event.
    struct Triggered: Sendable, Equatable, Hashable, Codable {
        /// ID of the schedule that recorded the event.
        var scheduleID: String

        /// Shared group IDs the recording schedule had at record time, if any.
        /// Canonical form: non-empty, de-duplicated, sorted.
        var sharedIDs: [String]?

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

        /// Shared group IDs the recording schedule had at record time, if any.
        /// Canonical form: non-empty, de-duplicated, sorted. Always nil for
        /// `backfill`, so legacy history never pollutes a group's pooled tally.
        var sharedIDs: [String]?

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

    /// Shared group IDs the recording schedule had at record time. Empty when
    /// it had none.
    var sharedIDs: [String] {
        switch self {
        case .triggered(let event): return event.sharedIDs ?? []
        case .execution(let event): return event.sharedIDs ?? []
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

    /// The scopes this event was recorded under: always its schedule, plus one
    /// for each shared group it carries.
    var scopes: [LedgerScope] {
        return [.schedule(scheduleID)] + sharedIDs.map { LedgerScope.shared($0) }
    }

    /// A copy of this event with `sharedIDs` replaced by their canonical form.
    ///
    /// Used at the storage boundary so every writer — direct recording and a
    /// compaction rewrite alike — persists the same de-duplicated, sorted
    /// rows and a matching encoded body, rather than depending on every
    /// caller (and every future one) canonicalizing before it gets there.
    func canonicalizingSharedIDs() -> LedgerEvent {
        switch self {
        case .triggered(var payload):
            payload.sharedIDs = LedgerSharedIDs.canonicalOrNil(payload.sharedIDs)
            return .triggered(payload)
        case .execution(var payload):
            payload.sharedIDs = LedgerSharedIDs.canonicalOrNil(payload.sharedIDs)
            return .execution(payload)
        }
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
        case sharedIDs = "shared_ids"
        case triggerID = "trigger_id"
        case timestamp
        case count
    }

    /// The single-ID key `sharedIDs` replaced. Bodies recorded by 21.0.0-beta.2/
    /// .3 are persisted as opaque JSON and outlive the Core Data model upgrade
    /// to v2 (a lightweight migration copies the blob's bytes as-is; it cannot
    /// rewrite what's inside them) — without this fallback, every such event
    /// would decode with no shared group at all, and the next compaction pass
    /// would re-encode it that way permanently.
    private enum LegacyCodingKeys: String, CodingKey {
        case sharedID = "shared_id"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scheduleID = try container.decode(String.self, forKey: .scheduleID)
        self.triggerID = try container.decodeIfPresent(String.self, forKey: .triggerID)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.count = try container.decodeIfPresent(Int.self, forKey: .count)

        if let sharedIDs = try container.decodeIfPresent([String].self, forKey: .sharedIDs) {
            self.sharedIDs = sharedIDs
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            self.sharedIDs = try legacy
                .decodeIfPresent(String.self, forKey: .sharedID)
                .map { [$0] }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.scheduleID, forKey: .scheduleID)
        try container.encodeIfPresent(self.sharedIDs, forKey: .sharedIDs)
        try container.encodeIfPresent(self.triggerID, forKey: .triggerID)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encodeIfPresent(self.count, forKey: .count)
    }
}

extension LedgerEvent.Execution {
    private enum CodingKeys: String, CodingKey {
        case scheduleID = "schedule_id"
        case sharedIDs = "shared_ids"
        case triggerID = "trigger_id"
        case timestamp
        case count
        case result
        case cancel
    }

    /// See ``LedgerEvent/Triggered/LegacyCodingKeys``: the same single-ID key,
    /// for the same reason, on the other event payload.
    private enum LegacyCodingKeys: String, CodingKey {
        case sharedID = "shared_id"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scheduleID = try container.decode(String.self, forKey: .scheduleID)
        self.triggerID = try container.decodeIfPresent(String.self, forKey: .triggerID)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.count = try container.decodeIfPresent(Int.self, forKey: .count)
        self.result = try container.decode(LedgerExecutionResult.self, forKey: .result)
        self.cancel = try container.decodeIfPresent(Bool.self, forKey: .cancel)

        if let sharedIDs = try container.decodeIfPresent([String].self, forKey: .sharedIDs) {
            self.sharedIDs = sharedIDs
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            self.sharedIDs = try legacy
                .decodeIfPresent(String.self, forKey: .sharedID)
                .map { [$0] }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.scheduleID, forKey: .scheduleID)
        try container.encodeIfPresent(self.sharedIDs, forKey: .sharedIDs)
        try container.encodeIfPresent(self.triggerID, forKey: .triggerID)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encodeIfPresent(self.count, forKey: .count)
        try container.encode(self.result, forKey: .result)
        try container.encodeIfPresent(self.cancel, forKey: .cancel)
    }
}
