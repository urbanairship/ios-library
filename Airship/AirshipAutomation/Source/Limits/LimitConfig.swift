/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Opts a schedule's limit evaluation into ledger-based counting with optional
/// exclusions.
///
/// The limit is always evaluated against the ledger — counting `execution`
/// events of every ``LedgerExecutionResult`` (never `triggered`) recorded under
/// either of the schedule's ledger IDs. This config only subtracts from that
/// tally via ``exclude``; it never changes the cap itself (the schedule's
/// `limit`). With no config, every such execution counts.
struct LimitConfig: Sendable, Codable, Equatable {

    /// Rules that remove recorded events from this schedule's limit tally.
    /// Events are always recorded; these rules only affect what counts against
    /// the cap. When absent, nothing is excluded and every execution counts.
    var exclude: ExclusionSet?

    enum CodingKeys: String, CodingKey {
        case exclude
    }
}

/// A set of exclusion rules combined with a boolean operator. An event is
/// excluded when it matches ANY rule in ``or`` (logical OR). Room is left to
/// add other combinators (e.g. `and`) later.
struct ExclusionSet: Sendable, Codable, Equatable {

    /// The rules OR'd together. An event is excluded when it matches any rule.
    var or: [ExclusionRule]

    enum CodingKeys: String, CodingKey {
        case or
    }

    init(or: [ExclusionRule]) {
        self.or = or
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.or = try container.decodeIfPresent([ExclusionRule].self, forKey: .or) ?? []
    }
}

/// Excludes recorded events from a schedule's limit tally. A rule subtracts
/// events that both come from ``source`` and satisfy ``match`` (every event
/// from the source when `match` is nil).
struct ExclusionRule: Sendable, Codable, Equatable {

    /// Which schedule's events this rule can subtract.
    var source: LedgerSource

    /// Which of that source's events to subtract. If nil, every event from the
    /// source is subtracted.
    var match: LedgerEventMatch?

    enum CodingKeys: String, CodingKey {
        case source
        case match
    }
}

/// Selects which schedule recorded the events a rule applies to, relative to
/// the evaluating schedule. Candidates are already scoped to the schedule's
/// ledger IDs (its schedule ID and shared ledger ID); this picks among the
/// schedule IDs within that scope by matching each event's `schedule_id`.
enum LedgerSource: Sendable, Equatable {

    /// Events recorded under the evaluating schedule's own schedule ID.
    case ownSchedule

    /// Every schedule sharing the ledger except the evaluating one.
    case otherSchedules

    /// A specific schedule, named absolutely by its schedule ID.
    case schedule(String)

    /// Any schedule sharing the ledger, including the evaluating schedule.
    case any

    /// A source type this SDK version does not recognize. Matches nothing, so a
    /// rule carrying it subtracts no events (a safe no-op that errs toward
    /// showing less).
    case unknown
}

/// Matches recorded ledger events by their own properties, discriminated by
/// event `type` so each variant only exposes fields that exist on that event.
enum LedgerEventMatch: Sendable, Equatable {

    /// Matches `triggered` events.
    case triggered(TriggeredMatch)

    /// Matches `execution` events, optionally narrowed by result and cancel.
    case execution(ExecutionMatch)

    /// A match type this SDK version does not recognize. Matches nothing, so a
    /// rule carrying it subtracts no events (a safe no-op).
    case unknown

    /// Matches `triggered` events. Has no result to match on.
    struct TriggeredMatch: Sendable, Equatable {
        /// Match only events recorded within this time span (against the event
        /// timestamp). If nil, no time bound is applied.
        var timeBounds: AirshipTimeCriteria?

        /// Match only events recorded under a matching shared group. If nil,
        /// shared group is not filtered.
        var sharedGroup: SharedGroupMatch?

        /// Match only events whose `trigger_id` equals this. If nil, all
        /// trigger IDs match.
        var triggerID: String?
    }

    /// Matches `execution` events, optionally narrowed by result and cancel.
    struct ExecutionMatch: Sendable, Equatable {
        /// Match only events recorded within this time span (against the event
        /// timestamp). If nil, no time bound is applied.
        var timeBounds: AirshipTimeCriteria?

        /// Match only events recorded under a matching shared group. If nil,
        /// shared group is not filtered.
        var sharedGroup: SharedGroupMatch?

        /// Execution results to match. If nil, all results match. Result values
        /// this SDK version does not recognize are dropped, so a rule that
        /// lists only unrecognized results matches nothing (errs toward showing
        /// less).
        var results: [LedgerExecutionResult]?

        /// Match only events whose `cancel` flag equals this. If nil, both
        /// cancelled and non-cancelled executions match.
        var cancel: Bool?

        /// Match only events whose `trigger_id` equals this. If nil, all
        /// trigger IDs match.
        var triggerID: String?
    }
}

/// Matches events by the shared group they were recorded under (their
/// `shared_id`), relative to the evaluating schedule's current shared group or
/// by an absolute ID.
enum SharedGroupMatch: Sendable, Equatable {

    /// Events recorded under the evaluating schedule's current shared group. If
    /// the schedule has no shared group, matches events recorded with none.
    case current

    /// Events NOT recorded under the evaluating schedule's current shared
    /// group, including events recorded with no shared group at all.
    case notCurrent

    /// Events recorded under a specific shared group, named absolutely.
    case id(String)

    /// A shared-group match type this SDK version does not recognize. Matches
    /// nothing (a safe no-op).
    case unknown
}

// MARK: - Codable

extension LedgerSource: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case scheduleID = "schedule_id"
    }

    private enum RawType: String {
        case ownSchedule = "own_schedule"
        case otherSchedules = "other_schedules"
        case schedule
        case any
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        switch RawType(rawValue: rawType) {
        case .ownSchedule: self = .ownSchedule
        case .otherSchedules: self = .otherSchedules
        case .schedule: self = .schedule(try container.decode(String.self, forKey: .scheduleID))
        case .any: self = .any
        case nil: self = .unknown
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ownSchedule:
            try container.encode(RawType.ownSchedule.rawValue, forKey: .type)
        case .otherSchedules:
            try container.encode(RawType.otherSchedules.rawValue, forKey: .type)
        case .schedule(let id):
            try container.encode(RawType.schedule.rawValue, forKey: .type)
            try container.encode(id, forKey: .scheduleID)
        case .any:
            try container.encode(RawType.any.rawValue, forKey: .type)
        case .unknown:
            try container.encode("unknown", forKey: .type)
        }
    }
}

extension LedgerEventMatch: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case timeBounds = "time_bounds"
        case sharedGroup = "shared_group"
        case results
        case cancel
        case triggerID = "trigger_id"
    }

    private enum RawType: String {
        case triggered
        case execution
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        let timeBounds = try container.decodeIfPresent(AirshipTimeCriteria.self, forKey: .timeBounds)
        let sharedGroup = try container.decodeIfPresent(SharedGroupMatch.self, forKey: .sharedGroup)
        let triggerID = try container.decodeIfPresent(String.self, forKey: .triggerID)

        switch RawType(rawValue: rawType) {
        case .triggered:
            self = .triggered(
                .init(
                    timeBounds: timeBounds,
                    sharedGroup: sharedGroup,
                    triggerID: triggerID
                )
            )
        case .execution:
            // Decode results leniently: drop any result value this SDK version
            // does not recognize. A rule listing only unknown results ends up
            // with an empty set, matching nothing.
            let results = try container.decodeIfPresent([String].self, forKey: .results)
                .map { $0.compactMap(LedgerExecutionResult.init(rawValue:)) }
            self = .execution(
                .init(
                    timeBounds: timeBounds,
                    sharedGroup: sharedGroup,
                    results: results,
                    cancel: try container.decodeIfPresent(Bool.self, forKey: .cancel),
                    triggerID: triggerID
                )
            )
        case nil:
            self = .unknown
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .triggered(let match):
            try container.encode(RawType.triggered.rawValue, forKey: .type)
            try container.encodeIfPresent(match.timeBounds, forKey: .timeBounds)
            try container.encodeIfPresent(match.sharedGroup, forKey: .sharedGroup)
            try container.encodeIfPresent(match.triggerID, forKey: .triggerID)
        case .execution(let match):
            try container.encode(RawType.execution.rawValue, forKey: .type)
            try container.encodeIfPresent(match.timeBounds, forKey: .timeBounds)
            try container.encodeIfPresent(match.sharedGroup, forKey: .sharedGroup)
            try container.encodeIfPresent(match.results?.map { $0.rawValue }, forKey: .results)
            try container.encodeIfPresent(match.cancel, forKey: .cancel)
            try container.encodeIfPresent(match.triggerID, forKey: .triggerID)
        case .unknown:
            try container.encode("unknown", forKey: .type)
        }
    }
}

extension SharedGroupMatch: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case sharedID = "shared_id"
    }

    private enum RawType: String {
        case current
        case notCurrent = "not_current"
        case id
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        switch RawType(rawValue: rawType) {
        case .current: self = .current
        case .notCurrent: self = .notCurrent
        case .id: self = .id(try container.decode(String.self, forKey: .sharedID))
        case nil: self = .unknown
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .current:
            try container.encode(RawType.current.rawValue, forKey: .type)
        case .notCurrent:
            try container.encode(RawType.notCurrent.rawValue, forKey: .type)
        case .id(let sharedID):
            try container.encode(RawType.id.rawValue, forKey: .type)
            try container.encode(sharedID, forKey: .sharedID)
        case .unknown:
            try container.encode("unknown", forKey: .type)
        }
    }
}

// MARK: - Matching

/// The evaluating schedule's identity for relative source/shared-group
/// matching.
struct LedgerLimitContext: Sendable, Equatable {
    /// The evaluating schedule's own ID.
    let scheduleID: String

    /// The evaluating schedule's current shared ledger ID, if any.
    let currentSharedID: String?
}

extension ExclusionSet {
    /// Whether `event` is removed from the tally: true when it matches ANY rule.
    func excludes(_ event: LedgerEvent, context: LedgerLimitContext, now: Date) -> Bool {
        return self.or.contains { $0.matches(event, context: context, now: now) }
    }
}

extension ExclusionRule {
    /// Whether this rule subtracts `event`: the event comes from ``source`` and
    /// (if present) satisfies ``match``.
    func matches(_ event: LedgerEvent, context: LedgerLimitContext, now: Date) -> Bool {
        guard self.source.matches(event, context: context) else { return false }
        guard let match else { return true }
        return match.matches(event, context: context, now: now)
    }
}

extension LedgerSource {
    func matches(_ event: LedgerEvent, context: LedgerLimitContext) -> Bool {
        switch self {
        case .ownSchedule: return event.scheduleID == context.scheduleID
        case .otherSchedules: return event.scheduleID != context.scheduleID
        case .schedule(let id): return event.scheduleID == id
        case .any: return true
        case .unknown: return false
        }
    }
}

extension LedgerEventMatch {
    func matches(_ event: LedgerEvent, context: LedgerLimitContext, now: Date) -> Bool {
        switch (self, event) {
        case (.triggered(let match), .triggered(let payload)):
            guard match.timeBounds?.isActive(date: payload.timestamp) ?? true else { return false }
            guard match.sharedGroup?.matches(sharedID: payload.sharedID, context: context) ?? true else {
                return false
            }
            if let triggerID = match.triggerID, payload.triggerID != triggerID { return false }
            return true

        case (.execution(let match), .execution(let payload)):
            guard match.timeBounds?.isActive(date: payload.timestamp) ?? true else { return false }
            guard match.sharedGroup?.matches(sharedID: payload.sharedID, context: context) ?? true else {
                return false
            }
            if let results = match.results, !results.contains(payload.result) { return false }
            if let cancel = match.cancel, (payload.cancel ?? false) != cancel { return false }
            if let triggerID = match.triggerID, payload.triggerID != triggerID { return false }
            return true

        default:
            // Match type does not apply to this event type (or is unknown).
            return false
        }
    }
}

extension SharedGroupMatch {
    func matches(sharedID: String?, context: LedgerLimitContext) -> Bool {
        switch self {
        case .current: return sharedID == context.currentSharedID
        case .notCurrent: return sharedID != context.currentSharedID
        case .id(let id): return sharedID == id
        case .unknown: return false
        }
    }
}
