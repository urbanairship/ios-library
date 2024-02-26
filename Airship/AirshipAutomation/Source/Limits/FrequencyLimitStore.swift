/* Copyright Airship and Contributors */

import CoreData
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

enum FrequencyLimitStoreError: Error, Sendable {
    case coreDataUnavailable
    case coreDataError
}

actor FrequencyLimitStore {

    private let coreData: UACoreData?

    init(
        appKey: String,
        inMemory: Bool
    ) {
        let bundle = AutomationResources.bundle
        if let modelURL = bundle.url(forResource: "UAFrequencyLimits", withExtension:"momd") {
            self.coreData = UACoreData(
                modelURL: modelURL,
                inMemory: inMemory,
                stores: ["Frequency-limits-\(appKey).sqlite"]
            )
        } else {
            self.coreData = nil
        }
    }

    init(
        config: RuntimeConfig
    ) {
        self.init(
            appKey: config.appKey,
            inMemory: false
        )
    }
    
    init(
        coreData: UACoreData
    ) {
        self.coreData = coreData
    }
    
    // MARK: -
    // MARK: Public Data Access

    func fetchConstraints(
        _ constraintIDs: [String]? = nil
    ) async throws -> [ConstraintInfo] {
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailable
        }

        AirshipLogger.trace(
            "Fetching frequency limit constraints"
        )
        
        return try await coreData.performWithResult { context in
            let result = try self.fetchConstraintsData(
                forIDs: constraintIDs,
                context: context
            )

            return result.map { data in
                return self.makeInfo(data: data)
            }
        }
    }

    func deleteConstraints(
        _ constraintIDs: [String]
    ) async throws {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailable
        }

        AirshipLogger.trace(
            "Deleting constraint IDs : \(constraintIDs)"
        )
        
        try await coreData.perform { context in
            let constraints = try self.fetchConstraintsData(
                forIDs: constraintIDs,
                context: context)
            constraints.forEach { constraint in
                context.delete(constraint)
            }
            UACoreData.safeSave(context)
        }
    }


    func saveOccurrences(
        _ occurrences: [Occurrence]
    ) async throws {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailable
        }
        
        AirshipLogger.trace("Saving occurrences \(occurrences)")

        let map: [String: [Occurrence]] = Dictionary(grouping: occurrences, by: { $0.constraintID })

        try await coreData.perform { context in

            try map.forEach { constraintID, occurrences in
                let constraintsData = try self.fetchConstraintsData(
                    forIDs: [constraintID],
                    context: context
                )

                if let constraintData = constraintsData.first {
                    try occurrences.forEach { occurrence in
                        let occurrenceData = try self.makeOccurrenceData(context: context)
                        occurrenceData.timestamp = occurrence.timestamp
                        constraintData.occurrence.insert(occurrenceData)
                    }
                }
            }
            
            UACoreData.safeSave(context)
        }
        
    }

    func upsertConstraint(
        _ constraint: FrequencyConstraint
    ) async throws {
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailable
        }

        AirshipLogger.trace(
            "Update constraint : \(constraint.identifier)"
        )

        try await coreData.perform { context in
            
            let result = try self.fetchConstraintsData(
                forIDs: [constraint.identifier],
                context: context
            )

            let data = try (result.first ?? self.makeConstraintData(context: context))
            data.identifier = constraint.identifier
            data.count = constraint.count
            data.range = constraint.range
            UACoreData.safeSave(context)
        }
    }

    // MARK: -
    // MARK: Helpers

    fileprivate nonisolated func fetchConstraintsData(
        forIDs constraintIDs: [String]? = nil,
        context: NSManagedObjectContext
    ) throws -> [FrequencyConstraintData] {
        
        let request: NSFetchRequest<FrequencyConstraintData> = FrequencyConstraintData.fetchRequest()
        request.includesPropertyValues = true

        if let constraintIDs = constraintIDs {
            request.predicate = NSPredicate(format: "identifier IN %@", constraintIDs)
        }
        
        return try context.fetch(request)
    }

    fileprivate nonisolated func makeConstraintData(
        context: NSManagedObjectContext
    ) throws -> FrequencyConstraintData {
        guard let data = NSEntityDescription.insertNewObject(
            forEntityName: FrequencyConstraintData.frequencyConstraintDataEntity,
            into:context) as? FrequencyConstraintData
        else {
            throw FrequencyLimitStoreError.coreDataError
        }

        return data
    }
    
    fileprivate nonisolated func makeOccurrenceData(
        context:NSManagedObjectContext
    ) throws -> OccurrenceData {

        guard 
            let data = NSEntityDescription.insertNewObject(
                forEntityName: OccurrenceData.occurrenceDataEntity,
                into:context
            ) as? OccurrenceData
        else {
            throw FrequencyLimitStoreError.coreDataError
        }

        return data
    }

    fileprivate nonisolated func makeInfo(data: FrequencyConstraintData) -> ConstraintInfo {
        return ConstraintInfo(
            constraint: FrequencyConstraint(
                identifier: data.identifier,
                range: data.range,
                count: data.count
            ),
            occurrences: data.occurrence.map({ occurrenceData in
                Occurrence(
                    constraintID: data.identifier,
                    timestamp: occurrenceData.timestamp
                )
            })
        )
    }

}



struct ConstraintInfo: Hashable, Equatable, Sendable {
    var constraint: FrequencyConstraint
    var occurrences: [Occurrence]
}


/// Represents a constraint on occurrences within a given time period.
/// 
@objc(UAFrequencyConstraintData)
fileprivate class FrequencyConstraintData: NSManagedObject {

    static let frequencyConstraintDataEntity = "UAFrequencyConstraintData"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: FrequencyConstraintData.frequencyConstraintDataEntity)
    }

    /// The constraint identifier.
    @NSManaged var identifier: String

     /// The time range.
    @NSManaged var range: TimeInterval

    /// The number of allowed occurrences.
    @NSManaged var count: UInt

    /// The occurrences
    @NSManaged var occurrence: Set<OccurrenceData>
}


@objc(UAOccurrenceData)
fileprivate class OccurrenceData: NSManagedObject {

    static let occurrenceDataEntity = "UAOccurrenceData"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: OccurrenceData.occurrenceDataEntity)
    }

    /// The timestamp
    @NSManaged var timestamp: Date

}
