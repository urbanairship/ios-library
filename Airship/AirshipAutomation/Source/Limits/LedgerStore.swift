/* Copyright Airship and Contributors */

import CoreData
import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Persists and queries ``LedgerEvent``s.
///
/// Scope of this store is persistence only: writing real events and reading
/// during limit checks are handled by higher layers. It supports appending
/// events, querying the events eligible for a schedule's limit evaluation
/// (events recorded under the schedule's own ID or any of its current shared
/// group IDs), and deleting events by scope.
protocol LedgerStoreProtocol: Sendable {
    /// Appends events to the ledger.
    /// - Parameter events: The events to append.
    func recordEvents(_ events: [LedgerEvent]) async throws

    /// Fetches the events eligible for a schedule's limit evaluation: every
    /// event recorded under the schedule's own ID, plus — only when the caller
    /// passes a non-empty `sharedIDs` — every event whose `schedule_id`
    /// matches one of them, or whose own `shared_ids` overlap them.
    ///
    /// The `schedule_id` side of that second check is what lets a schedule
    /// inherit a specifically-named schedule's pre-existing history, even
    /// history recorded before that schedule ever had a shared ID at all
    /// (e.g. backfilled pre-ledger history, which only ever carries a bare
    /// `schedule_id`) — one of the caller's `sharedIDs` can literally BE
    /// another schedule's own `schedule_id`. Passing `sharedIDs` only ever
    /// widens the result set, never narrows it — the caller decides whether to
    /// pass any at all based on whether this schedule has opted into shared
    /// events (see `.shared` on `LimitConfig`), and an event recorded under
    /// several groups the schedule also belongs to is still returned once.
    /// - Parameters:
    ///   - scheduleID: The evaluating schedule's ID.
    ///   - sharedIDs: The schedule's current shared group IDs, if it has
    ///     opted into shared events; empty to restrict to its own events only.
    /// - Returns: The eligible events.
    func events(scheduleID: String, sharedIDs: [String]) async throws -> [LedgerEvent]

    /// Deletes every event recorded under any of the given scopes.
    /// - Parameter scopes: The scopes to delete events for.
    func deleteEvents(scopes: [LedgerScope]) async throws

    /// Retention: drops every event whose recording scopes are all dead.
    ///
    /// An event survives while any of the IDs it was recorded under is still
    /// live, so a shared group's pooled history outlives individual variants. A
    /// live shared ID also keeps the events of the schedule it names, since that
    /// is how a schedule inherits history from the one it replaces. An event is
    /// deleted only when its `scheduleID` is in neither `liveScheduleIDs` nor
    /// `liveSharedIDs` **and** none of its `sharedIDs` is in `liveSharedIDs`.
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

    /// Whether `compact` has already forced its once-per-process reindex pass.
    ///
    /// A migrated (v1→v2) event's shared-group index is only recoverable by
    /// decoding its body — see `insertEvent`'s canonicalization and
    /// `LedgerEvent`'s legacy-key decode fallback — and nothing else ever
    /// leaves an event under-indexed, since every write from here on out goes
    /// through `insertEvent`, which always indexes correctly. So this
    /// condition can only ever be true once, immediately after an upgrade;
    /// forcing exactly one full pass per launch catches it without paying a
    /// full decode on every later `compact` call.
    private var hasVerifiedSharedIDIndex = false

    init(appKey: String, inMemory: Bool) {
        let bundle = AirshipAutomationResources.bundle
        if let modelURL = bundle.url(forResource: "AirshipLedger", withExtension: "momd") {
            self.coreData = UACoreData(
                name: "AirshipLedger",
                modelURL: modelURL,
                inMemory: inMemory,
                stores: ["AirshipLedger-\(appKey).sqlite"],
                recoverOnMigrationError: true
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
                try self.insertEvent(event, encoder: encoder, context: context)
            }
        }
    }

    func events(scheduleID: String, sharedIDs: [String]) async throws -> [LedgerEvent] {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        AirshipLogger.trace(
            "Fetching ledger events for schedule \(scheduleID) sharedIDs \(sharedIDs)"
        )

        return try await coreData.performWithResult { context in
            let predicate = try self.eligibilityPredicate(
                scheduleID: scheduleID, sharedIDs: sharedIDs, context: context
            )

            // `JSONDecoder` isn't thread-safe and this actor's `performWithResult`
            // closure can suspend, so use a closure-local decoder rather than a
            // shared one to avoid overlapping use from a re-entrant call.
            let decoder = JSONDecoder()
            return try self.fetchEvents(predicate: predicate, context: context)
                .map { try decoder.decode(LedgerEvent.self, from: $0.body) }
        }
    }

    /// The predicate `events(scheduleID:sharedIDs:)` fetches by: an event
    /// qualifies if it was recorded under this schedule's ID, OR — only when
    /// `sharedIDs` is non-empty — its `schedule_id` matches one of them, or
    /// its own `shared_ids` overlap them. Logical OR throughout, not AND:
    /// passing `sharedIDs` only ever widens the result set.
    ///
    /// The `scheduleID IN sharedIDs` branch is what lets a schedule inherit a
    /// specifically-named schedule's pre-existing history, even history
    /// recorded before that schedule ever had a shared ID at all (e.g.
    /// backfilled pre-ledger events, which only ever carry a bare
    /// `schedule_id`) — one of the caller's `sharedIDs` can literally BE
    /// another schedule's own `schedule_id`. It's a plain indexed-column
    /// match, so it costs nothing extra to include unconditionally alongside
    /// the group lookup.
    ///
    /// The shared-group half is resolved in two steps — matching rows first,
    /// then their events by object ID — rather than as one
    /// `ANY sharedIDs.value IN %@` predicate. The single-predicate form reads
    /// better but does not use the index on `value`: it scans, so its cost
    /// tracks the whole ledger rather than the matches. At 20,000 rows that
    /// measured 8.7ms against 0.16ms for this shape, and it degrades as the
    /// ledger fills, on a path every trigger hits.
    ///
    /// Factored out so the OR-compound shape is exercised by exactly one piece
    /// of code — a test built its own copy once and drifted from the real
    /// predicate without anyone noticing.
    private nonisolated func eligibilityPredicate(
        scheduleID: String,
        sharedIDs: [String],
        context: NSManagedObjectContext
    ) throws -> NSPredicate {
        var subpredicates: [NSPredicate] = [
            NSPredicate(format: "scheduleID == %@", scheduleID)
        ]

        if !sharedIDs.isEmpty {
            subpredicates.append(NSPredicate(format: "scheduleID IN %@", sharedIDs))

            if let eventIDs = try self.eventIDs(forSharedIDs: sharedIDs, context: context) {
                subpredicates.append(NSPredicate(format: "SELF IN %@", eventIDs))
            }
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
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
                case .shared(let id): NSPredicate(format: "ANY sharedIDs.value == %@", id)
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
            // schedule is gone AND none of its shared groups is still live. A
            // schedule ID that a live shared ID names is not gone, because
            // eligibility reads it as a shared group too. The shared-group half
            // is phrased as a SUBQUERY count rather than `NONE` so it stays
            // correct for events with no shared groups at all, whose subquery
            // is trivially empty and therefore dead.
            let scheduleScopeDead = NSPredicate(
                format: "NOT (scheduleID IN %@) AND NOT (scheduleID IN %@)",
                liveScheduleIDs,
                liveSharedIDs
            )
            let sharedDead = NSPredicate(
                format: "SUBQUERY(sharedIDs, $shared, $shared.value IN %@).@count == 0",
                liveSharedIDs
            )
            let predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [scheduleScopeDead, sharedDead]
            )
            try self.deleteEvents(predicate: predicate, context: context)
        }
    }

    func compact(now: Date) async throws {
        try await self.compact(now: now, maxEvents: LedgerCompactor.defaultMaxEvents)
    }

    /// How many shared-ID rows the store holds. Test-only.
    ///
    /// Exposed because shared-ID rows are otherwise invisible from outside: a
    /// leak here (a delete that drops events but strands their rows) would grow
    /// the store without ever changing a query result, so nothing else could
    /// catch it.
    func sharedIDRowCount() async throws -> Int {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        return try await coreData.performWithResult { context in
            let request: NSFetchRequest<any NSFetchRequestResult> =
                LedgerSharedIDData.fetchRequest()
            return try context.count(for: request)
        }
    }

    /// Records `event`, then runs the real `events(scheduleID:sharedIDs:)`
    /// eligibility predicate against it inside the same transaction, before the
    /// write is saved. Test-only.
    ///
    /// Exposed because the property it checks — that the query resolves
    /// against unsaved work in the same context — is unreachable from outside,
    /// since every public entry point saves before it returns. Goes through
    /// ``eligibilityPredicate(scheduleID:sharedIDs:context:)`` rather than
    /// calling ``eventIDs(forSharedIDs:context:)`` directly, so this guards the
    /// whole `scheduleID OR sharedIDs` shape `events` actually runs — including
    /// the `scheduleID` half — not just the shared-group lookup in isolation.
    func eventsBeforeSaving(
        recording event: LedgerEvent,
        scheduleID: String,
        sharedIDs: [String]
    ) async throws -> Int {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        return try await coreData.performWithResult { context in
            try self.insertEvent(event, encoder: JSONEncoder(), context: context)
            let predicate = try self.eligibilityPredicate(
                scheduleID: scheduleID, sharedIDs: sharedIDs, context: context
            )
            return try self.fetchEvents(predicate: predicate, context: context).count
        }
    }

    /// Cap-injectable variant used by tests to exercise the backstop path without
    /// seeding tens of thousands of rows.
    func compact(now: Date, maxEvents: Int) async throws {
        guard let coreData = self.coreData else {
            throw LedgerStoreError.coreDataUnavailable
        }

        // Read before the closure, which runs off-actor: this call's forced
        // pass (if any) is decided now, and `hasVerifiedSharedIDIndex` is only
        // set afterward, back on the actor, once the pass actually completes.
        let mustForceReindexCheck = !self.hasVerifiedSharedIDIndex

        try await coreData.perform { context in
            // Cheap pre-check before the full fetch+decode: compaction can only
            // remove rows when the ledger is over the global cap (backstop),
            // holds events old enough to age-bucket (older than `rawMaxAge`),
            // or — once per process, `mustForceReindexCheck` — hasn't yet been
            // verified free of under-indexed migrated events. The first two
            // are answerable from indexed columns without decoding any `body`,
            // so the common case — a small, all-recent, already-verified
            // ledger with nothing to merge — skips the whole decode.
            let countRequest: NSFetchRequest<any NSFetchRequestResult> =
                LedgerEventData.fetchRequest()
            let total = try context.count(for: countRequest)
            guard total > 0 else { return }

            if !mustForceReindexCheck,
               total <= maxEvents,
               let oldest = try self.oldestTimestamp(context: context),
               oldest >= now.addingTimeInterval(-LedgerCompactor.rawMaxAge) {
                return
            }

            // `JSONEncoder`/`JSONDecoder` aren't thread-safe and this actor's
            // `perform` closure can suspend, so use closure-local coders rather
            // than shared ones to avoid overlapping use from a re-entrant call.
            let decoder = JSONDecoder()

            let existing = try self.fetchEvents(
                predicate: nil, context: context, prefetchSharedIDs: true
            )
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

            // Merging isn't the only reason to rewrite. An event decoded via
            // the legacy `shared_id` fallback (a body a pre-v2 build wrote)
            // recovers its groups only in memory, right here — its stored rows
            // are still whatever the migration left, which is none. Detect
            // that mismatch and force the rewrite even when nothing merged, or
            // a migrated event's group is queryable again only in memory, for
            // exactly as long as the process that decoded it lives.
            let needsReindex = zip(existing, events).contains { entity, event in
                let indexed = Set(
                    (entity.sharedIDs?.allObjects as? [LedgerSharedIDData] ?? []).map(\.value)
                )
                return indexed != Set(LedgerSharedIDs.canonical(event.sharedIDs))
            }

            // An unchanged count with already-matching rows means nothing to
            // do; skip the rewrite to avoid churn.
            guard compacted.count < events.count || needsReindex else { return }

            AirshipLogger.trace(
                "Compacting ledger from \(events.count) to \(compacted.count) events"
            )

            // Object-graph deletes rather than a batch delete, so the cascade
            // rule clears each event's shared-ID rows with it.
            existing.forEach(context.delete)
            let encoder = JSONEncoder()
            try compacted.forEach { event in
                try self.insertEvent(event, encoder: encoder, context: context)
            }
        }

        // Back on the actor: only reached once the pass above actually
        // completes without throwing, so a failed attempt is retried by the
        // next `compact` call rather than being marked verified regardless.
        self.hasVerifiedSharedIDIndex = true
    }

    // MARK: - Helpers

    /// Object IDs of the events recorded under any of `sharedIDs`, found by
    /// querying the shared-ID rows on their own indexed `value` column.
    ///
    /// Returns nil when nothing matches, so the caller can leave the clause out
    /// entirely rather than build an `SELF IN ()` that matches nothing but still
    /// costs a term. De-duplicated because an event in several of the requested
    /// groups contributes one row per group, and only the distinct events are
    /// wanted.
    ///
    /// Deliberately a plain object fetch. Asking for just the `event` column via
    /// `dictionaryResultType` is the obvious way to avoid materializing these
    /// rows, but a dictionary fetch is resolved against the store alone and
    /// cannot see unsaved inserts, where the object fetch it would replace can.
    /// Every write here is saved before the block returns, so nothing is pending
    /// by the time this runs today — but a caller that ever recorded and queried
    /// within one block would silently miss its own events, and it costs nothing
    /// to keep that impossible: at 20,000 rows both forms measure a quarter of a
    /// millisecond, against 8.7ms for matching on the relationship directly.
    private nonisolated func eventIDs(
        forSharedIDs sharedIDs: [String],
        context: NSManagedObjectContext
    ) throws -> [NSManagedObjectID]? {
        let request: NSFetchRequest<LedgerSharedIDData> = LedgerSharedIDData.fetchRequest()
        request.predicate = NSPredicate(format: "value IN %@", sharedIDs)

        let ids = Set(try context.fetch(request).compactMap { $0.event?.objectID })
        return ids.isEmpty ? nil : Array(ids)
    }

    private nonisolated func fetchEvents(
        predicate: NSPredicate?,
        context: NSManagedObjectContext,
        prefetchSharedIDs: Bool = false
    ) throws -> [LedgerEventData] {
        let request: NSFetchRequest<LedgerEventData> = LedgerEventData.fetchRequest()
        request.includesPropertyValues = true
        request.predicate = predicate
        // Only compaction's reindex check reads `.sharedIDs` back off the
        // fetched entities; every other caller decodes `body` instead. Without
        // this, that check would fault the relationship in one query per row.
        if prefetchSharedIDs {
            request.relationshipKeyPathsForPrefetching = ["sharedIDs"]
        }
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
            // A shared-ID row is only reachable through its event, so a delete
            // that dropped events but left their rows would leak storage no
            // query could ever surface. The batch delete propagates the
            // relationship's cascade rule and takes them with it;
            // ``LedgerStoreOnDiskTest`` pins that, since the in-memory path
            // above gets the cascade from the object graph instead and would
            // not catch a regression here.
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }

    /// Inserts one event plus a row per shared group it was recorded under.
    ///
    /// The shared IDs live in their own indexed entity rather than a column on
    /// the event: an event can now belong to several groups at once, and a
    /// limit check has to find it by any of them.
    ///
    /// Canonicalizes `sharedIDs` here rather than trusting the caller, so
    /// every writer — direct recording and a compaction rewrite alike — ends
    /// up with the same de-duplicated, sorted rows and a matching encoded
    /// body, instead of only whichever caller happened to canonicalize first.
    private nonisolated func insertEvent(
        _ event: LedgerEvent,
        encoder: JSONEncoder,
        context: NSManagedObjectContext
    ) throws {
        let canonical = event.canonicalizingSharedIDs()

        let entity = try self.makeEventData(context: context)
        entity.scheduleID = canonical.scheduleID
        entity.timestamp = canonical.timestamp
        entity.body = try encoder.encode(canonical)

        try canonical.sharedIDs.forEach { sharedID in
            let shared = try self.makeSharedIDData(context: context)
            shared.value = sharedID
            shared.event = entity
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

    private nonisolated func makeSharedIDData(
        context: NSManagedObjectContext
    ) throws -> LedgerSharedIDData {
        guard
            let data = NSEntityDescription.insertNewObject(
                forEntityName: LedgerSharedIDData.entityName,
                into: context
            ) as? LedgerSharedIDData
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
/// scope, `type`, `trigger_id`, `variant_audience_id`, `result`, or `cancel`
/// never merge.
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
        /// Canonical (sorted, de-duplicated), so two events belonging to the
        /// same set of groups hash and compare equal regardless of the order
        /// their IDs arrived in.
        var sharedIDs: [String]
        var triggerID: String?
        var variantAudienceID: String?
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
                sharedIDs: LedgerSharedIDs.canonical(payload.sharedIDs),
                triggerID: payload.triggerID,
                variantAudienceID: payload.variantAudienceID,
                result: nil,
                cancel: nil
            )
        case .execution(let payload):
            return Key(
                type: .execution,
                scheduleID: payload.scheduleID,
                sharedIDs: LedgerSharedIDs.canonical(payload.sharedIDs),
                triggerID: payload.triggerID,
                variantAudienceID: payload.variantAudienceID,
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
                    sharedIDs: payload.sharedIDs,
                    triggerID: payload.triggerID,
                    variantAudienceID: payload.variantAudienceID,
                    timestamp: newest,
                    count: total
                )
            )
        case .execution(let payload):
            return .execution(
                .init(
                    scheduleID: payload.scheduleID,
                    sharedIDs: payload.sharedIDs,
                    triggerID: payload.triggerID,
                    variantAudienceID: payload.variantAudienceID,
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
        if left.sharedIDs != right.sharedIDs {
            return left.sharedIDs.lexicographicallyPrecedes(right.sharedIDs)
        }

        let leftKey = key(for: left)
        let rightKey = key(for: right)
        if leftKey.type != rightKey.type {
            return leftKey.type.rawValue < rightKey.type.rawValue
        }
        if (leftKey.triggerID ?? "") != (rightKey.triggerID ?? "") {
            return (leftKey.triggerID ?? "") < (rightKey.triggerID ?? "")
        }
        if (leftKey.variantAudienceID ?? "") != (rightKey.variantAudienceID ?? "") {
            return (leftKey.variantAudienceID ?? "") < (rightKey.variantAudienceID ?? "")
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

    /// One row per shared group ID the recording schedule had at record time.
    /// Empty when it had none.
    @NSManaged var sharedIDs: NSSet?

    /// The event's timestamp, promoted out of ``body`` into an indexed column so
    /// compaction can cheaply test whether any event is old enough to merge
    /// without decoding every row.
    @NSManaged var timestamp: Date

    /// The JSON-encoded ``LedgerEvent``.
    @NSManaged var body: Data
}

/// One shared group ID an event was recorded under, promoted out of ``body``
/// into its own indexed entity so a limit check can find events by group
/// without decoding every row.
@objc(UALedgerSharedIDData)
fileprivate class LedgerSharedIDData: NSManagedObject {

    static let entityName: String = "UALedgerSharedIDData"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: LedgerSharedIDData.entityName)
    }

    /// The shared group ID.
    @NSManaged var value: String

    /// The event recorded under it.
    @NSManaged var event: LedgerEventData?
}
