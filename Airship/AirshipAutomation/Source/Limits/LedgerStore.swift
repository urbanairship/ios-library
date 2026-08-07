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

    /// The JSON-encoded ``LedgerEvent``.
    @NSManaged var body: Data
}
