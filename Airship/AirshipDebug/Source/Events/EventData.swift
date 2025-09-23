/* Copyright Airship and Contributors */

public import CoreData
import Foundation

/// - Note: For internal use only. :nodoc:
@objc(EventData)
public class EventData: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EventData> {
        return NSFetchRequest<EventData>(entityName: "EventData")
    }

    @NSManaged public var eventBody: String?
    @NSManaged public var eventID: String?
    @NSManaged public var eventType: String?
    @NSManaged public var eventDate: Date?
}
