/* Copyright Airship and Contributors */

import CoreData
import Foundation

@objc(UAOccurrenceData)
class OccurrenceData: NSManagedObject {
    
    static let occurenceDataEntity = "UAOccurrenceData"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: OccurrenceData.occurenceDataEntity)
    }
    
    /// The parent constraint.
    @NSManaged var constraint: FrequencyConstraintData
    
    /// The timestamp
    @NSManaged var timestamp: Date
    
}
