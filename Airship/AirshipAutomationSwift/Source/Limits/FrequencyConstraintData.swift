/* Copyright Airship and Contributors */

import CoreData
import Foundation

/// Represents a constraint on occurrences within a given time period.
@objc(UAFrequencyConstraintData)
class FrequencyConstraintData: NSManagedObject {

    static let frequencyConstraintDataEntity = "UAFrequencyConstraintData"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: FrequencyConstraintData.frequencyConstraintDataEntity)
    }
    
    /// The constraint identifier.
    @NSManaged var identifier: String

     /// The time range.
    @NSManaged var range: TimeInterval

    /// The number of allowed occurences.
    @NSManaged var count: UInt
    
}
