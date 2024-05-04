/* Copyright Airship and Contributors */

import CoreData
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

class EventDataManager {

    private let maxAge = TimeInterval(172800)  // 2 days
    private let appKey: String
    private let coreData: UACoreData

    public init(appKey: String) {
        self.appKey = appKey
        self.coreData = UACoreData(
            modelURL: DebugResources.bundle()
                .url(
                    forResource: "AirshipDebugEventData",
                    withExtension: "momd"
                )!,
            inMemory: false,
            stores: ["AirshipDebugEventData-\(appKey).sqlite"]
        )
        
        Task {
            await self.trimDatabase()
        }
    }

    private func trimDatabase() async {
        
        let cutOffDate = Date().addingTimeInterval(-self.maxAge)
        
        await coreData.performBlockIfStoresExist { isSafe, context in
            guard isSafe else { return }

            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = EventData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventDate < %@", cutOffDate as NSDate)
            
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                _ = try context.execute(batchDeleteRequest)
            } catch {
                print("Failed to execute request: \(error)")
            }
        }
    }

    func saveEvent(_ event: AirshipEvent) async {
        
        await self.coreData.safePerform { isSafe, context in
            guard isSafe else { return }

            let persistedEvent = EventData(
                entity: EventData.entity(),
                insertInto: context
            )

            persistedEvent.eventBody = event.body
            persistedEvent.eventType = event.type
            persistedEvent.eventDate = event.date
            persistedEvent.eventID = event.identifier

            UACoreData.safeSave(context)
        }
    }

    func events(searchString: String? = nil) async -> [AirshipEvent] {
        return await coreData.safePerform { isSafe, context in
            guard isSafe else {
                return []
            }

            let fetchRequest: NSFetchRequest = EventData.fetchRequest()
            fetchRequest.fetchLimit = 200
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(
                    key: #keyPath(EventData.eventDate),
                    ascending: false
                )
            ]

            if let searchString = searchString, !searchString.isEmpty {
                fetchRequest.predicate = NSPredicate(
                    format:
                        "eventID CONTAINS[cd] %@ OR eventType CONTAINS[cd] %@",
                    searchString,
                    searchString
                )
            }

            do {
                let result = try context.fetch(fetchRequest)
                let events = result.compactMap { data -> AirshipEvent? in
                    if let eventType = data.eventType,
                        let eventBody = data.eventBody,
                        let eventDate = data.eventDate,
                        let eventID = data.eventID
                    {
                        return AirshipEvent(
                            identifier: eventID,
                            type: eventType,
                            date: eventDate,
                            body: eventBody
                        )
                    }
                    return nil
                }

                return events
            } catch {
                if let error = error as NSError? {
                    print(
                        "ERROR: error fetching events list - \(error), \(error.userInfo)"
                    )
                }
                return []
            }
        } ?? []
    }
}
