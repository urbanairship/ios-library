import Foundation
import CoreData

@objc(EventData)
public class EventData: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EventData> {
        return NSFetchRequest<EventData>(entityName: "EventData")
    }

    @NSManaged public var data: String?
    @NSManaged public var eventID: String?
    @NSManaged public var eventType: String?
    @NSManaged public var time: Double
}
