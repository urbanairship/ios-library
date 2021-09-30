/* Copyright Airship and Contributors */

import UIKit
import CoreData

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

protocol EventDataManagerDelegate {
    func eventAdded()
}

class EventDataManager: NSObject, AnalyticsEventConsumerProtocol {
    private let eventsKey = "events"
    private let eventsNotificationName = "UAEventAdded"

    private let storageDaysSettingKey = "AirshipDebug-EventStorageDays"

    // The number of days events will be stored by default.
    private let defaultStorageDays = 2

    // Days of event backlog - must be greater than or equal to the default of 2 days.
    var storageDays:Int {
        get {
            let persisted = UserDefaults.standard.integer(forKey:storageDaysSettingKey)
            return persisted >= defaultStorageDays ? persisted : defaultStorageDays
        }

        set (storageDays) {
            UserDefaults.standard.set(storageDays, forKey: storageDaysSettingKey)
        }
    }

    var delegate:EventDataManagerDelegate?

    static let shared = EventDataManager()

    private lazy var persistentContainer:NSPersistentContainer = {
        let momdName = "AirshipEventData"

        guard let modelURL = DebugResources.bundle().url(forResource: momdName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }

        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }

        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)

        container.loadPersistentStores(completionHandler: { (storeDescriptioon, error) in
            if let error = error as NSError? {
                print("ERROR: error loading Debug Kit Data Manager persistent stores - \(error), \(error.userInfo)")
            }
        })

        return container
    }()

    override init() {
        super.init()

        // Prune events by stale date on start
        batchDeleteEventsOlderThanStorageDays()
    }

    @objc func eventAdded(event: Event, eventID: String, eventDate: Date) {
        let airshipEvent = AirshipEvent(event: event, identifier:eventID, date:eventDate)
        EventDataManager.shared.saveEvent(airshipEvent)

        delegate?.eventAdded()
    }

    private func saveContext(_ context:NSManagedObjectContext) {
        guard context.hasChanges else {
            return
        }

        do {
            try context.save()
        } catch {
            if let error = error as NSError? {
                print("ERROR: error saving Debug Data Manager context - \(error), \(error.userInfo)")
            }
        }
    }

    private func batchDeleteEventsOlderThanStorageDays() {
        let context = persistentContainer.viewContext

        let startOfTodayDate = Calendar.current.startOfDay(for: Date())

        // Storage days defaults to 2
        let storageDaysInterval = Calendar.current.date(byAdding:.day, value:-(self.storageDays), to:startOfTodayDate)!.timeIntervalSince1970

        print("Deleting events older than \(storageDays) days.")

        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = EventData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format:"time < %f", storageDaysInterval)
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest:fetchRequest)

        do {
            _ = try context.execute(batchDeleteRequest)
        } catch {
            print("Failed to execute request: \(error)")
        }
    }

    private func saveEvent(_ event:AirshipEvent) {
        let context = persistentContainer.viewContext

        let persistedEvent = EventData(entity: EventData.entity(), insertInto:context)
        persistedEvent.data = event.data
        persistedEvent.eventID = event.eventID
        persistedEvent.time = event.time
        persistedEvent.eventType = event.eventType

        saveContext(context)
    }

    func fetchAllEvents() -> [AirshipEvent] {
        return fetchEventsContaining(searchString: nil, timeWindow:nil)
    }

    func fetchEventsContaining(searchString:String?, timeWindow:DateInterval?) -> [AirshipEvent] {
        var eventDatas:[Any] = []
        var events:[AirshipEvent] = []

        let context = persistentContainer.viewContext
        let fetchRequest:NSFetchRequest = EventData.fetchRequest()

        var subpredicates:[NSPredicate] = []

        if let str = searchString, !str.isEmpty {
            subpredicates.append(NSPredicate(format: "eventID CONTAINS[cd] %@ OR eventType CONTAINS[cd] %@", str, str))
        }

        if let timeWindow = timeWindow {
            let start:Double = timeWindow.start.timeIntervalSince1970
            let end:Double = start + timeWindow.duration

            print("Filtering dates events from \(start.toPrettyDateString()) - \(end.toPrettyDateString())")

            subpredicates.append(NSPredicate(format:"time >= %f AND time < %f", start, end))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:subpredicates)

        do {
            eventDatas = try context.fetch(fetchRequest)
        } catch {
            if let error = error as NSError? {
                print("ERROR: error fetching events list - \(error), \(error.userInfo)")
            }
        }

        for eventData in eventDatas {
            guard let data = eventData as? EventData else {
                continue
            }

            let event = AirshipEvent(eventData:data)
            events.append(event)
        }

        return events
    }
}
