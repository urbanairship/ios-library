/* Copyright Airship and Contributors */

import CoreData
import Foundation

/// NOTE: For internal use only. :nodoc:
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
    @NSManaged public var data: [AnyHashable: Any]

    /// The remote data info as json encoded data.
    @objc
    @NSManaged public var remoteDataInfo: Data?
}
