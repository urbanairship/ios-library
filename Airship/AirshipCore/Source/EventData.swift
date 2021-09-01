/* Copyright Airship and Contributors */

import CoreData
import Foundation

/// CoreData class representing the backing data for
/// a UAEvent.
///
/// This class should not ordinarily be used directly.
/// For internal use only. :nodoc:
@objc(UAEventData)
public class EventData: NSManagedObject {

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
