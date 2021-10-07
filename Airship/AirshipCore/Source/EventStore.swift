/* Copyright Airship and Contributors */

import Foundation
import CoreData

/// Event data store. For internal use only.
/// :nodoc:
@objc(UAEventStore)
public class EventStore : NSObject, EventStoreProtocol {
    private static let fileFormat = "Events-%@.sqlite"
    private static let eventDataEntityName = "UAEventData"

    private var coreData: UACoreData
    private var storeName: String?

    @objc
    public init(config: RuntimeConfig?) {
        let storeName = String(format: EventStore.fileFormat, config?.appKey ?? "")
        let modelURL = AirshipCoreResources.bundle.url(forResource: "UAEvents", withExtension: "momd")
        self.coreData = UACoreData(modelURL: modelURL!, inMemory: false, stores: [storeName])

        super.init()
    }


    @objc
    public func save(_ event: Event, eventID: String, eventDate: Date, sessionID: String) {
        self.coreData.safePerform { [weak self] isSafe, context in
            guard isSafe else {
                AirshipLogger.error("Unable to save event: \(event). Persistent store unavailable")
                return
            }

            let eventTime = String(format: "%f", eventDate.timeIntervalSince1970)

            self?.storeEvent(
                withID: eventID,
                eventType: event.eventType,
                eventTime: eventTime,
                eventBody: event.data,
                sessionID: sessionID,
                context: context)

            UACoreData.safeSave(context)
        }
    }

    @objc
    public func fetchEvents(
        withLimit limit: Int,
        completionHandler: @escaping ([EventData]) -> Void
    ) {
        self.coreData.safePerform({ isSafe, context in
            if !isSafe {
                completionHandler([])
                return
            }

            let request = NSFetchRequest<NSFetchRequestResult>(entityName: EventStore.eventDataEntityName)
            request.fetchLimit = limit
            request.sortDescriptors = [NSSortDescriptor(key: "storeDate", ascending: true)]

            do {
                let result = try context.fetch(request) as? [EventData] ?? []
                completionHandler(result)
                UACoreData.safeSave(context)
            } catch {
                AirshipLogger.error("Error fetching events: \(error)")
                completionHandler([])
            }
        })
    }

    @objc
    public func deleteEvents(withIDs eventIDs: [String]?) {
        self.coreData.safePerform({ isSafe, context in
            if !isSafe {
                return
            }

            let request = NSFetchRequest<NSFetchRequestResult>(entityName: EventStore.eventDataEntityName)
            if let eventIDs = eventIDs {
                request.predicate = NSPredicate(format: "identifier IN %@", eventIDs)
            }

            do {
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                try context.execute(deleteRequest)
                UACoreData.safeSave(context)
            } catch {
                AirshipLogger.error("Error deleting analytics events: \(error)")
            }
        })
    }

    @objc
    public func deleteAllEvents() {
        self.coreData.performBlockIfStoresExist({ isSafe, context in
            if !isSafe {
                return
            }

            let request = NSFetchRequest<NSFetchRequestResult>(entityName: EventStore.eventDataEntityName)

            do {
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                try context.execute(deleteRequest)
                UACoreData.safeSave(context)
            } catch {
                AirshipLogger.error("Error deleting analytics events: \(error)")
            }
        })
    }

    @objc
    public func trimEvents(toStoreSize maxSize: UInt) {
        self.coreData.safePerform({ [weak self] isSafe, context in
            guard isSafe, let self = self else {
                return
            }

            while self.fetchTotalEventSize(with: context) > maxSize {
                guard let sessionID = self.fetchOldestSessionID(with: context),
                      self.deleteSession(sessionID, context: context) else {
                    return
                }
            }

            UACoreData.safeSave(context)
        })
    }

    private func deleteSession(_ sessionID: String, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: EventStore.eventDataEntityName)
        request.predicate = NSPredicate(format: "sessionID == %@", sessionID)

        do {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
            return true
        } catch {
            AirshipLogger.error("Error deleting session: \(sessionID)")
            return false;

        }
    }

    private func fetchOldestSessionID(with context: NSManagedObjectContext) -> String? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: EventStore.eventDataEntityName)
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "storeDate", ascending: true)]
        request.propertiesToFetch = ["sessionID"]

        do {
            let result = try context.fetch(request) as? [EventData] ?? []
            return result.first?.sessionID
        } catch {
            AirshipLogger.error("Error fetching oldest sessionID: \(error)")
            return nil
        }

    }

    private func fetchTotalEventSize(with context: NSManagedObjectContext) -> Int {
        let sumDescription = NSExpressionDescription()
        sumDescription.name = "sum"
        sumDescription.expression = NSExpression(
            forFunction: "sum:",
            arguments: [NSExpression(forKeyPath: "bytes")])
        sumDescription.expressionResultType = .doubleAttributeType

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: EventStore.eventDataEntityName)
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

    private func storeEvent(withID eventID: String, eventType: String, eventTime: String,
                            eventBody: Any, sessionID: String, context: NSManagedObjectContext) {
        do {
            let json = try JSONUtils.data(eventBody, options: [])

            if let eventData = NSEntityDescription.insertNewObject(forEntityName: EventStore.eventDataEntityName, into: context) as? EventData {
                eventData.sessionID = sessionID
                eventData.type = eventType
                eventData.time = eventTime
                eventData.identifier = eventID
                eventData.data = json
                eventData.storeDate = Date()

                // Approximate size
                var count = 0
                count += eventData.sessionID?.count ?? 0
                count += eventData.type?.count ?? 0
                count += eventData.time?.count ?? 0
                count += eventData.identifier?.count ?? 0
                count += eventData.data?.count ?? 0
                eventData.bytes = NSNumber(value: count)

                AirshipLogger.debug("Event saved: \(eventID)")
            } else {
                AirshipLogger.error("Unable to insert event data: \(json)")
            }
        } catch {
            AirshipLogger.error("Unable to save event: \(error)")
        }
    }
}
