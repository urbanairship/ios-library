/* Copyright Airship and Contributors */

import CoreData
import UIKit
import AirshipCore

final class EventDataManager: Sendable {

    private let maxAge = TimeInterval(172800)  // 2 days
    private let appKey: String
    private let coreData: UACoreData

    public init(appKey: String) {
        self.appKey = appKey
        self.coreData = UACoreData(
            name: "AirshipDebugEventData",
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
        
        let cutOffDate = Date().advanced(by: -self.maxAge)
        
        do {
            try await coreData.perform(skipIfStoreNotCreated: true) { context in
                let fetchRequest: NSFetchRequest<any NSFetchRequestResult> = EventData.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "eventDate < %@", cutOffDate as NSDate)

                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(batchDeleteRequest)
            }
        } catch {
            print("Failed to execute request: \(error)")
        }
    }

    func saveEvent(_ event: AirshipEvent) async {
        
        do {
            try await self.coreData.perform { context in
                let persistedEvent = EventData(
                    entity: EventData.entity(),
                    insertInto: context
                )

                persistedEvent.eventBody = event.body
                persistedEvent.eventType = event.type
                persistedEvent.eventDate = event.date
                persistedEvent.eventID = event.identifier
            }
        } catch {
            print("Failed to save event: \(error)")

        }
    }

    func events(searchString: String? = nil) async -> [AirshipEvent] {
        do {
            return try await coreData.performWithResult { context in
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
            }

        } catch {
            print(
                "ERROR: error fetching events list - \(error)"
            )
            return []
        }
    }
}
