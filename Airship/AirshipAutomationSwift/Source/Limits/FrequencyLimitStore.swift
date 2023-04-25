/* Copyright Airship and Contributors */

import CoreData
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

enum FrequencyLimitStoreError: Error {
    case coreDataUnavailble
    case coreDataError
}

actor FrequencyLimitStore {

    private let coreData: UACoreData?

    init(
        name: String,
        inMemory: Bool
    ) {
        let bundle = AutomationResources.bundle
        if let modelURL = bundle.url(forResource: "UAFrequencyLimits", withExtension:"momd") {
            self.coreData = UACoreData(
                modelURL:modelURL,
                inMemory:inMemory,
                stores:[name],
                mergePolicy:NSMergeByPropertyObjectTrumpMergePolicy)
        } else {
            self.coreData = nil
        }
    }

    init(
        config: RuntimeConfig
    ) {
        self.init(
            name: String(format:"Frequency-limits-%@.sqlite", config.appKey),
            inMemory: false)
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
    ) async throws -> [FrequencyConstraint] {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailble
        }

        AirshipLogger.trace(
            "Fetching frenquency limit constraints"
        )
        
        return try await coreData.performWithResult { context in
            let data = try self.fetchConstraintsData(
                forIDs: constraintIDs,
                context: context)
            return self.constraints(fromData: data)
        }

    }

    func deleteConstraints(
        _ constraintIDs: [String]
    ) async throws {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailble
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

    func deleteConstraint(
        _ constraint: FrequencyConstraint
    ) async throws {
        return try await self.deleteConstraints([constraint.identifier])
    }

    func fetchOccurrences(
        forConstraintID constraintID: String
    ) async throws -> [Occurrence] {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailble
        }

        AirshipLogger.trace(
            "Fetching occurrences data for constraint ID : \(constraintID)"
        )

        return try await coreData.performWithResult { context in
            let data = try self.fetchOccurrencesData(
                forConstraintID: constraintID,
                context: context)
            return self.occurrences(fromData: data)
        }
    }

    func saveOccurrences(
        occurrences: [Occurrence]
    ) async throws {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailble
        }
        
        AirshipLogger.trace("Saving occurrences data")
        
        try await coreData.perform { context in
            
            try occurrences.forEach { occurrence in
                let constraintsData = try self.fetchConstraintsData(
                    forIDs: [occurrence.parentConstraintID],
                    context: context)
                
                guard let constraintData = constraintsData.first else {
                    throw FrequencyLimitStoreError.coreDataUnavailble
                }
                
                try self.addData(
                    forOccurrence: occurrence,
                    constraintData: constraintData,
                    context: context)
            }
            
            UACoreData.safeSave(context)
        }
        
    }

    func saveOrUpdateConstraint(
        _ constraint: FrequencyConstraint
    ) async throws {
        
        guard let coreData = self.coreData else {
            throw FrequencyLimitStoreError.coreDataUnavailble
        }

        AirshipLogger.trace(
            "Saving constraint : \(constraint.identifier)"
        )

        try await coreData.perform { context in
            
            let result = try self.fetchConstraintsData(
                forIDs: [constraint.identifier],
                context: context)
            
            if let data = result.first {
                data.identifier = constraint.identifier
                data.count = constraint.count
                data.range = constraint.range
            } else {
                try self.addData(forConstraint: constraint, context: context)
            }
            
            UACoreData.safeSave(context)
        }
    }

    // MARK: -
    // MARK: Helpers

    nonisolated func fetchConstraintsData(
        forIDs constraintIDs: [String]? = nil,
        context: NSManagedObjectContext
    ) throws -> [FrequencyConstraintData] {
        
        let request: NSFetchRequest<FrequencyConstraintData> = FrequencyConstraintData.fetchRequest()
        
        if let constraintIDs = constraintIDs {
            request.predicate = NSPredicate(format: "identifier IN %@", constraintIDs)
        }
        
        return try context.fetch(request)
    }
    
    nonisolated func fetchOccurrencesData(
        forConstraintID constraintID:String,
        context:NSManagedObjectContext
    ) throws -> [OccurrenceData] {
        let request: NSFetchRequest<OccurrenceData> = OccurrenceData.fetchRequest()
        request.predicate = NSPredicate(format: "constraint.identifier == %@", constraintID)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending:true)]
        
        return try context.fetch(request)
    }
    
    nonisolated func addData(
        forConstraint constraint: FrequencyConstraint,
        context: NSManagedObjectContext
    ) throws {
        
        guard let data = NSEntityDescription.insertNewObject(
            forEntityName: FrequencyConstraintData.frequencyConstraintDataEntity,
            into:context) as? FrequencyConstraintData
        else {
            throw FrequencyLimitStoreError.coreDataError
        }
        
        data.identifier = constraint.identifier
        data.count = constraint.count
        data.range = constraint.range
    }
    
    nonisolated func addData(
        forOccurrence occurrence:Occurrence,
        constraintData:FrequencyConstraintData,
        context:NSManagedObjectContext
    ) throws {
        
        guard let data = NSEntityDescription.insertNewObject(
            forEntityName: OccurrenceData.occurenceDataEntity,
            into:context) as? OccurrenceData
        else {
            throw FrequencyLimitStoreError.coreDataError
        }
        
        data.timestamp = occurrence.timestamp
        data.constraint = constraintData
    }
    
    // MARK: -
    // MARK: Conversion

    nonisolated func constraints(
        fromData constraintsData: [FrequencyConstraintData]
    ) -> [FrequencyConstraint] {
        
        return constraintsData.compactMap{
            FrequencyConstraint(
                identifier: $0.identifier,
                range: $0.range,
                count: $0.count)
        }
        
    }
    
    nonisolated func occurrences(
        fromData occurrencesData: [OccurrenceData]
    ) -> [Occurrence] {
        
        return occurrencesData.compactMap {
            Occurrence(
                withParentConstraintID: $0.constraint.identifier,
                timestamp:$0.timestamp)
        }
        
    }
    
}

