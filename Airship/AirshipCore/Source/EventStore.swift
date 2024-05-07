/* Copyright Airship and Contributors */

import CoreData
import Foundation

actor EventStore {
    private static let eventDataEntityName = "UAEventData"
    private static let fetchEventLimit = 500

    private var coreData: UACoreData
    private var storeName: String?
    private nonisolated let inMemory: Bool

    init(appKey: String, inMemory: Bool = false) {
        self.inMemory = inMemory
        let modelURL = AirshipCoreResources.bundle.url(
            forResource: "UAEvents",
            withExtension: "momd"
        )
        self.coreData = UACoreData(
            name: Self.eventDataEntityName,
            modelURL: modelURL!,
            inMemory: inMemory,
            stores: ["Events-\(appKey).sqlite"]
        )
    }

    func save(
        event: AirshipEventData
    ) async throws {
        try await self.coreData.perform { context in
            try self.saveEvent(event: event, context: context)
        }
    }

    func fetchEvents(
        maxBatchSizeKB: UInt
    ) async throws -> [AirshipEventData] {
        return try await self.coreData.performWithResult { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: EventStore.eventDataEntityName
            )
            request.fetchLimit = EventStore.fetchEventLimit
            request.sortDescriptors = [
                NSSortDescriptor(key: "storeDate", ascending: true)
            ]

            let fetchResult = try context.fetch(request) as? [EventData] ?? []
            let batchSizeBytesLimit = maxBatchSizeKB * 1024
            var batchSize = 0
            var events: [AirshipEventData] = []
            for eventData in fetchResult {
                let bytes = eventData.bytes?.intValue ?? 0
                if ((batchSize + bytes) > batchSizeBytesLimit) {
                    break
                }

                do {
                    events.append(
                        try self.convert(internalEventData: eventData)
                    )
                    batchSize += bytes
                } catch {
                    AirshipLogger.error("Unable to read event, deleting. \(error)")
                    context.delete(eventData)
                }
            }
            return events
        }
    }

    func hasEvents() async throws -> Bool {
        return try await self.coreData.performWithResult { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: EventStore.eventDataEntityName
            )
            return try context.count(for: request) > 0
        }
    }

    func deleteEvents(eventIDs: [String]) async throws {
        try await self.coreData.perform { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: EventStore.eventDataEntityName
            )
            
            request.predicate = NSPredicate(
                format: "identifier IN %@",
                eventIDs
            )
            
            do {
                if self.inMemory {
                    request.includesPropertyValues = false
                    let events = try context.fetch(request) as? [NSManagedObject]
                    events?.forEach { event in
                        context.delete(event)
                    }
                } else {
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    try context.execute(deleteRequest)
                }
            } catch {
                AirshipLogger.error("Error deleting analytics events: \(error)")
            }
        }
    }

    func deleteAllEvents() async throws {
        try await self.coreData.perform(skipIfStoreNotCreated: true) { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: EventStore.eventDataEntityName
            )

            do {
                if self.inMemory {
                    request.includesPropertyValues = false
                    let events = try context.fetch(request) as? [NSManagedObject]
                    events?.forEach { event in
                        context.delete(event)
                    }
                } else {
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    try context.execute(deleteRequest)
                }
            } catch {
                AirshipLogger.error("Error deleting analytics events: \(error)")
            }
        }
    }

    func trimEvents(maxStoreSizeKB: UInt) async throws {
        let maxBytes = maxStoreSizeKB * 1024
        try await self.coreData.perform { context in
            while self.fetchTotalEventSize(with: context) > maxBytes {
                guard let sessionID = self.fetchOldestSessionID(with: context),
                    self.deleteSession(sessionID, context: context)
                else {
                    return
                }
            }
        }
    }

    nonisolated private func deleteSession(
        _ sessionID: String,
        context: NSManagedObjectContext
    ) -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(
            entityName: EventStore.eventDataEntityName
        )
        request.predicate = NSPredicate(format: "sessionID == %@", sessionID)

        do {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
            return true
        } catch {
            AirshipLogger.error("Error deleting session: \(sessionID)")
            return false
        }
    }

    nonisolated private func fetchOldestSessionID(with context: NSManagedObjectContext)
        -> String?
    {
        let request = NSFetchRequest<NSFetchRequestResult>(
            entityName: EventStore.eventDataEntityName
        )
        request.fetchLimit = 1
        request.sortDescriptors = [
            NSSortDescriptor(key: "storeDate", ascending: true)
        ]
        request.propertiesToFetch = ["sessionID"]

        do {
            let result = try context.fetch(request) as? [EventData] ?? []
            return result.first?.sessionID
        } catch {
            AirshipLogger.error("Error fetching oldest sessionID: \(error)")
            return nil
        }

    }

    nonisolated private func fetchTotalEventSize(with context: NSManagedObjectContext)
        -> Int
    {
        guard !self.inMemory else {
            return 0
        }

        let sumDescription = NSExpressionDescription()
        sumDescription.name = "sum"
        sumDescription.expression = NSExpression(
            forFunction: "sum:",
            arguments: [NSExpression(forKeyPath: "bytes")]
        )
        sumDescription.expressionResultType = .doubleAttributeType

        let request = NSFetchRequest<NSFetchRequestResult>(
            entityName: EventStore.eventDataEntityName
        )
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [sumDescription]

        do {
            let result = try context.fetch(request) as? [[String: Int]] ?? []
            return result.first?["sum"] ?? 0
        } catch {
            AirshipLogger.error("Error trimming analytic event store: \(error)")
            return 0
        }
    }

    nonisolated private func saveEvent(
        event: AirshipEventData,
        context: NSManagedObjectContext
    ) throws {
        if let eventData = NSEntityDescription.insertNewObject(
            forEntityName: EventStore.eventDataEntityName,
            into: context
        ) as? EventData {
            eventData.sessionID = event.sessionID
            eventData.type = event.type
            eventData.identifier = event.id
            eventData.data = try event.body.toData()
            eventData.storeDate = event.date

            // Approximate size
            var count = 0
            count += eventData.sessionID?.count ?? 0
            count += eventData.type?.count ?? 0
            count += eventData.time?.count ?? 0
            count += eventData.identifier?.count ?? 0
            count += eventData.data?.count ?? 0
            eventData.bytes = NSNumber(value: count)

            AirshipLogger.debug("Event saved: \(event)")
        } else {
            AirshipLogger.error("Failed to save event: \(event)")
        }
    }

    nonisolated private func date(internalEventData: EventData) -> Date? {
        // Stopped using the time field on new events. Will remove
        // in a future SDK version.
        if let time = internalEventData.time, let time = Double(time) {
            return Date(timeIntervalSince1970: time)
        }

        return internalEventData.storeDate
    }

    nonisolated private func convert(
        internalEventData: EventData
    ) throws -> AirshipEventData {
        guard let sessionID = internalEventData.sessionID,
              let id = internalEventData.identifier,
              let type = internalEventData.type,
              let date = date(internalEventData: internalEventData)
        else {
            throw AirshipErrors.error("Invalid event data")
        }

        return AirshipEventData(
            body: try AirshipJSON.from(data: internalEventData.data),
            id: id,
            date: date,
            sessionID: sessionID,
            type: type
        )
    }
}

// Internal core data entity
@objc(UAEventData)
fileprivate class EventData: NSManagedObject {

    /// The event's session ID.
    @objc
    @NSManaged public dynamic var sessionID: String?

    /// The event's Data.
    @NSManaged public dynamic var data: Data?

    /// The event's creation time.
    @objc
    @NSManaged public dynamic var time: String?

    /// The event's number of bytes.
    @objc
    @NSManaged public dynamic var bytes: NSNumber?

    /// The event's type.
    @objc
    @NSManaged public dynamic var type: String?

    /// The event's identifier.
    @objc
    @NSManaged public dynamic var identifier: String?

    /// The event's store date.
    @objc
    @NSManaged public dynamic var storeDate: Date?
}

