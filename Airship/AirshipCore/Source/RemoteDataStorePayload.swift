/* Copyright Airship and Contributors */

import Foundation
import CoreData

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataStorePayload)
class RemoteDataStorePayload: NSManagedObject {
    
    /// The payload type
    @objc
    @NSManaged public var type: String
    
    /// The timestamp of the most recent change to this data payload
    @objc
    @NSManaged public var timestamp: Date
    
    /// The actual data associated with this payload
    @objc
    @NSManaged public var data: [AnyHashable : Any]
    
    /// The metadata associated with this payload
    ///
    /// Contains important metadata such as locale.
    @objc
    @NSManaged public var metadata: [AnyHashable : Any]?
}
