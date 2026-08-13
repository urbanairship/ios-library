/* Copyright Airship and Contributors */

import CoreData
import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Persists and queries ``LedgerEvent``s.
///
/// Scope of this store is persistence only: writing real events and reading
/// during limit checks are handled by higher layers. It supports appending
/// events, querying the events eligible for a schedule's limit evaluation
/// (events recorded under the schedule's own ID or its current shared group
/// ID), and deleting events by scope.
protocol LedgerStoreProtocol: Sendable {
    /// Appends events to the ledger.
    /// - Parameter events: The events to append.
    func recordEvents(_ events: [LedgerEvent]) async throws

    /// Fetches the events eligible for a schedule's limit evaluation: every
    /// event recorded under the schedule's own ID, plus every event recorded
    /// under the schedule's current shared group ID (if any).
    ///
    /// The two IDs are matched with a logical **OR**, not an AND: an event
    /// qualifies if its `schedule_id` matches `scheduleID` OR its `shared_id`
    /// matches `sharedID`. Despite the AND-like parameter list, an event does
    /// not need to match both — passing a `sharedID` widens the result set, it
    /// does not narrow it.
    /// - Parameters:
    ///   - scheduleID: The evaluating schedule's ID.
    ///   - sharedID: The schedule's current shared group ID, if any.
    /// - Returns: The eligible events.
    func events(scheduleID: String, sharedID: String?) async throws -> [LedgerEvent]

    /// Deletes every event recorded under any of the given scopes.
    /// - Parameter scopes: The scopes to delete events for.
    func deleteEvents(scopes: [LedgerScope]) async throws

    /// Retention: drops every event whose recording scopes are all dead.
    ///
    /// An event survives while any of the IDs it was recorded under is still
    /// live, so a shared group's pooled history outlives individual variants. An
    /// event is deleted only when its `scheduleID` is not in `liveScheduleIDs`
    /// **and** its `sharedID` (if any) is not in `liveSharedIDs`.
    /// - Parameters:
    ///   - liveScheduleIDs: Schedule IDs that still reference the ledger.
    ///   - liveSharedIDs: Shared group IDs that still reference the ledger.
    func retainEvents(liveScheduleIDs: Set<String>, liveSharedIDs: Set<String>) async throws

    /// Compaction: merges mergeable events per the age-tiered policy and
    /// enforces the global backstop cap, rewriting the store in place.
    /// - Parameter now: Reference time used to bucket events by age.
    func compact(now: Date) async throws
}

fileprivate enum LedgerStoreError: Error {
    case coreDataUnavailable
    case coreDataError
}

actor LedgerStore: LedgerStoreProtocol {

    private let coreData: UACoreData?
    private let inMemory: Bool

    init(appKey: String, inMemory: Bool) {
        let bundle = AirshipAutomationResources.bundle
        if let modelURL = bundle.url(forResource: "AirshipLedger", withExtension: "momd") {
            self.coreData = UACoreData(
                name: "AirshipLedger",
                modelURL: modelURL,
                inMemory: inMemory,
                stores: ["AirshipLedger-\(appKey).sqlite"]
            )
        } else {
            self.coreData = nil
        }
        self.inMemory = inMemory
    }

    init(config: RuntimeConfig) {
        self.init(appKey: config.appCredentials.appKey, inMemory: false)
    }

    func recordEvents(_ events: [LedgerEvent]) async throws {
        guard !events.isEmpty else { return }

        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        AirshipLogger.trace("Recording ledger events: \(events)")

        try await coreData.perform { context in
            // `JSONEncoder` isn't thread-safe and this actor's `perform` closure
            // can suspend, so use a closure-local encoder rather than a shared
            // one to avoid overlapping use from a re-entrant call.
            let encoder = JSONEncoder()
            try events.forEach { event in
                let entity = try self.makeEventData(context: context)
                entity.scheduleID = event.scheduleID
                entity.sharedID = event.sharedID
                entity.timestamp = event.timestamp
                entity.body = try encoder.encode(event)
            }
        }
    }

    func events(scheduleID: String, sharedID: String?) async throws -> [LedgerEvent] {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        AirshipLogger.trace(
            "Fetching ledger events for schedule \(scheduleID) sharedID \(sharedID ?? "nil")"
        )

        return try await coreData.performWithResult { context in
            // Logical OR, not AND: an event qualifies if it was recorded under
            // this schedule's ID OR under its current shared group ID. Both are
            // not required despite the AND-like parameter list.
            let predicate: NSPredicate = if let sharedID {
                NSPredicate(format: "scheduleID == %@ OR sharedID == %@", scheduleID, sharedID)
            } else {
                NSPredicate(format: "scheduleID == %@", scheduleID)
            }

            // `JSONDecoder` isn't thread-safe and this actor's `performWithResult`
            // closure can suspend, so use a closure-local decoder rather than a
            // shared one to avoid overlapping use from a re-entrant call.
            let decoder = JSONDecoder()
            return try self.fetchEvents(predicate: predicate, context: context)
                .map { try decoder.decode(LedgerEvent.self, from: $0.body) }
        }
    }

    func deleteEvents(scopes: [LedgerScope]) async throws {
        guard !scopes.isEmpty else { return }

        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        AirshipLogger.trace("Deleting ledger events for scopes: \(scopes)")

        try await coreData.perform { context in
            let subpredicates: [NSPredicate] = scopes.map { scope in
                switch scope {
                case .schedule(let id): NSPredicate(format: "scheduleID == %@", id)
                case .shared(let id): NSPredicate(format: "sharedID == %@", id)
                }
            }

            let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
            try self.deleteEvents(predicate: predicate, context: context)
        }
    }

    func retainEvents(liveScheduleIDs: Set<String>, liveSharedIDs: Set<String>) async throws {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        AirshipLogger.trace(
            "Retaining ledger events for live schedules \(liveScheduleIDs) shared \(liveSharedIDs)"
        )

        try await coreData.perform { context in
            // Delete an event only when it's orphaned on both axes: its recording
            // schedule is gone AND (it has no shared group OR that group is gone).
            // The predicates are written to be NULL-safe under SQL batch delete —
            // `scheduleID` is non-optional, and the `sharedID == nil` clause keeps
            // rows with no shared group from evaluating to SQL NULL.
            let scheduleDead = NSPredicate(format: "NOT (scheduleID IN %@)", liveScheduleIDs)
            let sharedDead = NSPredicate(
                format: "sharedID == nil OR NOT (sharedID IN %@)", liveSharedIDs
            )
            let predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [scheduleDead, sharedDead]
            )
            try self.deleteEvents(predicate: predicate, context: context)
        }
    }

    func compact(now: Date) async throws {
        try await self.compact(now: now, maxEvents: LedgerCompactor.defaultMaxEvents)
    }

    /// Cap-injectable variant used by tests to exercise the backstop path without
    /// seeding tens of thousands of rows.
    func compact(now: Date, maxEvents: Int) async throws {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        try await coreData.perform { context in
            // Cheap pre-check before the full fetch+decode: compaction can only
            // remove rows when the ledger is over the global cap (backstop) or
            // holds events old enough to age-bucket (older than `rawMaxAge`).
            // Both are answerable from indexed columns without decoding any
            // `body`, so the common case — a small, all-recent ledger with
            // nothing to merge — skips the whole decode.
            let countRequest: NSFetchRequest<any NSFetchRequestResult> =
                LedgerEventData.fetchRequest()
            let total = try context.count(for: countRequest)
            guard total > 0 else { return }

            if total <= maxEvents,
               let oldest = try self.oldestTimestamp(context: context),
               oldest >= now.addingTimeInterval(-LedgerCompactor.rawMaxAge) {
                return
            }

            // `JSONEncoder`/`JSONDecoder` aren't thread-safe and this actor's
            // `perform` closure can suspend, so use closure-local coders rather
            // than shared ones to avoid overlapping use from a re-entrant call.
            let decoder = JSONDecoder()

            let existing = try self.fetchEvents(predicate: nil, context: context)
            guard !existing.isEmpty else { return }

            let events = try existing.map { try decoder.decode(LedgerEvent.self, from: $0.body) }
            let compacted = LedgerCompactor.compact(events, now: now, maxEvents: maxEvents)

            // Non-mergeable singletons can keep the ledger over the cap; trace it
            // rather than silently exceed the bound.
            if compacted.count > maxEvents {
                AirshipLogger.trace(
                    "Ledger still holds \(compacted.count) events after compaction, over the cap of \(maxEvents); remaining events are non-mergeable."
                )
            }

            // Compaction only ever removes rows (by merging), so an unchanged
            // count means nothing merged — skip the rewrite to avoid churn.
            guard compacted.count < events.count else { return }

            AirshipLogger.trace(
                "Compacting ledger from \(events.count) to \(compacted.count) events"
            )

            existing.forEach(context.delete)
            let encoder = JSONEncoder()
            try compacted.forEach { event in
                let entity = try self.makeEventData(context: context)
                entity.scheduleID = event.scheduleID
                entity.sharedID = event.sharedID
                entity.timestamp = event.timestamp
                entity.body = try encoder.encode(event)
            }
        }
    }

    // MARK: - Helpers

    private nonisolated func fetchEvents(
        predicate: NSPredicate?,
        context: NSManagedObjectContext
    ) throws -> [LedgerEventData] {
        let request: NSFetchRequest<LedgerEventData> = LedgerEventData.fetchRequest()
        request.includesPropertyValues = true
        request.predicate = predicate
        return try context.fetch(request)
    }

    /// The smallest stored `timestamp`, or nil when the ledger is empty. Fetched
    /// as a dictionary of just the `timestamp` column so no `body` blob is loaded.
    private nonisolated func oldestTimestamp(
        context: NSManagedObjectContext
    ) throws -> Date? {
        let request = NSFetchRequest<NSDictionary>(
            entityName: LedgerEventData.entityName
        )
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["timestamp"]
        request.sortDescriptors = [
            NSSortDescriptor(key: "timestamp", ascending: true)
        ]
        request.fetchLimit = 1
        return try context.fetch(request).first?["timestamp"] as? Date
    }

    private nonisolated func deleteEvents(
        predicate: NSPredicate?,
        context: NSManagedObjectContext
    ) throws {
        let request: NSFetchRequest<any NSFetchRequestResult> = LedgerEventData.fetchRequest()
        request.predicate = predicate

        if self.inMemory {
            request.includesPropertyValues = false
            let results = try context.fetch(request) as? [NSManagedObject]
            results?.forEach(context.delete)
        } else {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }

    private nonisolated func makeEventData(
        context: NSManagedObjectContext
    ) throws -> LedgerEventData {
        guard
            let data = NSEntityDescription.insertNewObject(
                forEntityName: LedgerEventData.entityName,
                into: context
            ) as? LedgerEventData
        else {
            throw LedgerStoreError.coreDataError
        }
        return data
    }
}

/// Pure ledger-compaction math, kept separate from persistence so the merge
/// and bucketing logic is unit-testable without Core Data.
///
/// Compaction merges events that are *mergeable* — identical in every field
/// except `timestamp` and `count`, recorded under the same scope — into one
/// event that sums `count` and keeps the newest `timestamp`. Events differing in
/// scope, `type`, `trigger_id`, `result`, or `cancel` never merge.
///
/// How aggressively mergeable events actually merge depends on their age, so
/// recent history keeps full timestamp precision:
/// - younger than a year: raw (never merged by time)
/// - one to two years: merged into monthly buckets
/// - older than two years: merged into yearly buckets
///
/// A global backstop guards against unbounded growth: if the ledger still holds
/// more than ``maxEvents`` after age-tiered merging, whole mergeable groups are
/// collapsed across all ages, oldest history first, until under the cap.
enum LedgerCompactor {

    /// Events younger than this stay raw (never merged by time). One year.
    static let rawMaxAge: TimeInterval = 365 * 86400

    /// Events at least this old collapse into yearly buckets. Two years.
    static let yearlyMinAge: TimeInterval = 2 * 365 * 86400

    /// Global cap before the age-agnostic backstop kicks in.
    static let defaultMaxEvents: Int = 10_000

    /// UTC so bucketing is stable regardless of device locale/timezone.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }()

    /// The fields that must match for two events to be mergeable. `timestamp`
    /// and `count` are deliberately excluded: timestamp is bucketed by age and
    /// count is summed.
    struct Key: Hashable {
        var type: LedgerEventType
        var scheduleID: String
        var sharedID: String?
        var triggerID: String?
        var result: LedgerExecutionResult?
        var cancel: Bool?
    }

    /// The time bucket an event merges within, coarsening with age.
    enum Bucket: Hashable {
        /// Younger than a year: the exact timestamp, so distinct times never merge.
        case raw(Date)
        /// One to two years old: calendar month.
        case monthly(year: Int, month: Int)
        /// Older than two years: calendar year.
        case yearly(year: Int)
    }

    private struct BucketKey: Hashable {
        var key: Key
        var bucket: Bucket
    }

    static func key(for event: LedgerEvent) -> Key {
        switch event {
        case .triggered(let payload):
            return Key(
                type: .triggered,
                scheduleID: payload.scheduleID,
                sharedID: payload.sharedID,
                triggerID: payload.triggerID,
                result: nil,
                cancel: nil
            )
        case .execution(let payload):
            return Key(
                type: .execution,
                scheduleID: payload.scheduleID,
                sharedID: payload.sharedID,
                triggerID: payload.triggerID,
                result: payload.result,
                cancel: payload.cancel
            )
        }
    }

    static func bucket(for timestamp: Date, now: Date, calendar: Calendar) -> Bucket {
        let age = now.timeIntervalSince(timestamp)
        if age < rawMaxAge {
            return .raw(timestamp)
        }

        let components = calendar.dateComponents([.year, .month], from: timestamp)
        let year = components.year ?? 0
        if age < yearlyMinAge {
            return .monthly(year: year, month: components.month ?? 0)
        }
        return .yearly(year: year)
    }

    /// Compacts `events` and returns the merged set in a deterministic order.
    static func compact(
        _ events: [LedgerEvent],
        now: Date,
        maxEvents: Int = defaultMaxEvents,
        calendar: Calendar = utcCalendar
    ) -> [LedgerEvent] {
        guard !events.isEmpty else { return [] }

        // 1. Age-tiered merge: group by (mergeable key, age bucket), merge each.
        var buckets: [BucketKey: [LedgerEvent]] = [:]
        for event in events {
            let bucketKey = BucketKey(
                key: key(for: event),
                bucket: bucket(for: event.timestamp, now: now, calendar: calendar)
            )
            buckets[bucketKey, default: []].append(event)
        }

        var merged = buckets.values.compactMap(merge)

        // 2. Backstop: if still over the cap, collapse whole keys across all ages,
        //    oldest history first, until under the cap.
        if merged.count > maxEvents {
            merged = applyBackstop(merged, maxEvents: maxEvents)
        }

        return merged.sorted(by: ordering)
    }

    /// Merges events known to share a ``Key``: sums `count`, keeps the newest
    /// timestamp. A single event is returned untouched to avoid rewriting its
    /// original `count`/`timestamp`; an empty input returns nil.
    private static func merge(_ events: [LedgerEvent]) -> LedgerEvent? {
        guard let first = events.first else { return nil }
        guard events.count > 1 else { return first }

        let total = events.reduce(0) { $0 + $1.count }
        let newest = events.map(\.timestamp).max() ?? first.timestamp

        switch first {
        case .triggered(let payload):
            return .triggered(
                .init(
                    scheduleID: payload.scheduleID,
                    sharedID: payload.sharedID,
                    triggerID: payload.triggerID,
                    timestamp: newest,
                    count: total
                )
            )
        case .execution(let payload):
            return .execution(
                .init(
                    scheduleID: payload.scheduleID,
                    sharedID: payload.sharedID,
                    triggerID: payload.triggerID,
                    timestamp: newest,
                    count: total,
                    result: payload.result,
                    cancel: payload.cancel
                )
            )
        }
    }

    private static func applyBackstop(_ events: [LedgerEvent], maxEvents: Int) -> [LedgerEvent] {
        var groups: [Key: [LedgerEvent]] = [:]
        for event in events {
            groups[key(for: event), default: []].append(event)
        }

        // Collapse the groups holding the oldest events first.
        let orderedKeys = groups.keys.sorted { left, right in
            let leftOldest = groups[left]?.map(\.timestamp).min() ?? .distantFuture
            let rightOldest = groups[right]?.map(\.timestamp).min() ?? .distantFuture
            return leftOldest < rightOldest
        }

        var count = events.count
        for key in orderedKeys {
            guard count > maxEvents else { break }
            guard let group = groups[key], group.count > 1, let mergedGroup = merge(group) else { continue }
            groups[key] = [mergedGroup]
            count -= (group.count - 1)
        }

        return groups.values.flatMap { $0 }
    }

    /// Stable ordering for deterministic output. Ties are broken all the way down
    /// the mergeable-key fields so the result never depends on fetch/iteration
    /// order (two events that are equal on every field here would have merged).
    private static func ordering(_ left: LedgerEvent, _ right: LedgerEvent) -> Bool {
        if left.timestamp != right.timestamp {
            return left.timestamp < right.timestamp
        }
        if left.scheduleID != right.scheduleID {
            return left.scheduleID < right.scheduleID
        }
        if (left.sharedID ?? "") != (right.sharedID ?? "") {
            return (left.sharedID ?? "") < (right.sharedID ?? "")
        }

        let leftKey = key(for: left)
        let rightKey = key(for: right)
        if leftKey.type != rightKey.type {
            return leftKey.type.rawValue < rightKey.type.rawValue
        }
        if (leftKey.triggerID ?? "") != (rightKey.triggerID ?? "") {
            return (leftKey.triggerID ?? "") < (rightKey.triggerID ?? "")
        }
        if (leftKey.result?.rawValue ?? "") != (rightKey.result?.rawValue ?? "") {
            return (leftKey.result?.rawValue ?? "") < (rightKey.result?.rawValue ?? "")
        }
        return (leftKey.cancel.map(String.init) ?? "") < (rightKey.cancel.map(String.init) ?? "")
    }
}

@objc(UALedgerEventData)
fileprivate class LedgerEventData: NSManagedObject {

    static let entityName: String = "UALedgerEventData"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: LedgerEventData.entityName)
    }

    /// ID of the schedule that recorded the event.
    @NSManaged var scheduleID: String

    /// Shared group ID the recording schedule had at record time, if any.
    @NSManaged var sharedID: String?

    /// The event's timestamp, promoted out of ``body`` into an indexed column so
    /// compaction can cheaply test whether any event is old enough to merge
    /// without decoding every row.
    @NSManaged var timestamp: Date

    /// The JSON-encoded ``LedgerEvent``.
    @NSManaged var body: Data
}
