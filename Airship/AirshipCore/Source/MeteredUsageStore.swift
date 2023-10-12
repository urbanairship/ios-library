import Foundation
import CoreData

final class MeteredUsageStore: Sendable {
    private static let fileFormat = "MeteredUsage-%@.sqlite"
    private static let eventDataEntityName = "UAMeteredUsageEventData"
    private static let fetchEventLimit = 500

    private let coreData: UACoreData
    private let inMemory: Bool

    init(appKey: String,
         inMemory: Bool = false
    ) {
        self.inMemory = inMemory
        let storeName = String(
            format: MeteredUsageStore.fileFormat,
            appKey
        )
        let modelURL = AirshipCoreResources.bundle.url(
            forResource: "UAMeteredUsage",
            withExtension: "momd"
        )
        self.coreData = UACoreData(
            modelURL: modelURL!,
            inMemory: inMemory,
            stores: [storeName]
        )
    }

    func saveEvent(_ event: AirshipMeteredUsageEvent) async throws {
        try await self.coreData.perform { context in
            let eventData = NSEntityDescription.insertNewObject(
                forEntityName: MeteredUsageStore.eventDataEntityName,
                into: context
            ) as? MeteredUsageEventData

            guard let eventData = eventData else {
                throw AirshipErrors.error("Failed to MeteredUsageEventData")
            }

            eventData.identifier = event.eventID
            eventData.data = try AirshipJSON.defaultEncoder.encode(event)

            UACoreData.safeSave(context)
        }
    }

    func deleteAll() async throws {
        try await self.coreData.perform(skipIfStoreNotCreated: true) { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: MeteredUsageStore.eventDataEntityName
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
                UACoreData.safeSave(context)
            } catch {
                AirshipLogger.error("Error deleting usage events: \(error)")
            }
        }
    }

    func deleteEvents(_ events: [AirshipMeteredUsageEvent]) async throws {
        let eventIDs = events.map { $0.eventID }
        try await self.coreData.perform { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: MeteredUsageStore.eventDataEntityName
            )

            request.predicate = NSPredicate(
                format: "identifier IN %@",
                eventIDs
            )

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

            UACoreData.safeSave(context)
        }
    }

    func getEvents() async throws -> [AirshipMeteredUsageEvent] {
        return try await self.coreData.performWithResult { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: MeteredUsageStore.eventDataEntityName
            )
            request.fetchLimit = MeteredUsageStore.fetchEventLimit
            let fetchResult = try context.fetch(request) as? [MeteredUsageEventData] ?? []

            let events: [AirshipMeteredUsageEvent] = fetchResult.compactMap { eventData in
                guard let data = eventData.data else {
                    AirshipLogger.error("Unable to read event, deleting. \(eventData)")
                    context.delete(eventData)
                    return nil
                }

                do {
                    return try AirshipJSON.defaultDecoder.decode(AirshipMeteredUsageEvent.self, from: data)
                } catch {
                    AirshipLogger.error("Unable to read event, deleting. \(error)")
                    context.delete(eventData)
                    return nil
                }
            }

            UACoreData.safeSave(context)
            return events
        }
    }
}

// Internal core data entity
@objc(UAMeteredUsageEventData)
fileprivate class MeteredUsageEventData: NSManagedObject {
    /// The event's Data.
    @NSManaged public dynamic var data: Data?

    /// The event's identifier.
    @objc
    @NSManaged public dynamic var identifier: String?
}
