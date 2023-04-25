/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

class FrequencyLimitManager {
    private var occurrencesMap: [FrequencyConstraint : [Occurrence]]
    private var pendingOccurrences: [Occurrence]
    private let frequencyLimitStore: FrequencyLimitStore
    private let date: AirshipDateProtocol

    init(
        dataStore: FrequencyLimitStore,
        date: AirshipDateProtocol
    ) {
        self.frequencyLimitStore = dataStore
        self.date = date
        self.pendingOccurrences = []
        self.occurrencesMap = [:]
    }
    
    convenience init(
        config: RuntimeConfig
    ) {
        self.init(
            dataStore: FrequencyLimitStore(config: config),
            date: AirshipDate())
    }
    
    func getFrequencyChecker(
        constraintIDs: [String]
    ) async -> FrequencyChecker? {
        
        guard let constraints = await fetchConstraints(constraintIDs) else {
            return nil
        }
        
        return await createFrequencyChecker(constraints)
    }

    func addOrUpdateConstraints(
        _ constraints: [FrequencyConstraint]
    ) async {
            
        do {
            let currentConstraints = try await self.frequencyLimitStore.fetchConstraints()
            
            var constraintIDMap: [String: FrequencyConstraint] = [:]
            currentConstraints.forEach { constraint in
                constraintIDMap[constraint.identifier] = constraint
            }
            
            for constraint in constraints {
                if let existing = constraintIDMap[constraint.identifier] {
                    //Update constraint
                    constraintIDMap[constraint.identifier] = nil;
                    if (existing.range != constraint.range) {
                        let resutl = await deleteConstraint(constraint)
                        if (resutl) {
                            await self.saveConstraint(constraint)
                        }
                    } else {
                        await self.saveConstraint(constraint)
                    }
                } else {
                    // Add constraint
                    await self.saveConstraint( constraint)
                }
            }
            
            do {
                try await self.frequencyLimitStore.deleteConstraints(Array(constraintIDMap.keys))
            } catch {
                AirshipLogger.error("Unable to delete constraints")
            }
            
        } catch {
            AirshipLogger.error("Unable to fetch constraints")
        }
    }

    func saveConstraint(_ constraint: FrequencyConstraint) async {
        
        do {
            try await self.frequencyLimitStore.saveOrUpdateConstraint(constraint)
        } catch {
            AirshipLogger.error("Unable to save constraint: \(constraint)")
        }

    }

    func deleteConstraint(_ constraint: FrequencyConstraint) async -> Bool {
        
        do {
            try await self.frequencyLimitStore.deleteConstraint(constraint)
            return true
        } catch {
            AirshipLogger.error("Unable to delete constraint: \(constraint)");
            return false
        }
    }

    func fetchConstraints(
        _ constraintIDs: [String]
    ) async -> [FrequencyConstraint]? {
        
        do {
            let constraints = try await self.frequencyLimitStore.fetchConstraints(constraintIDs)
            
            for constraint in constraints {
                do {
                    var occurrences = try await self.frequencyLimitStore.fetchOccurrences(forConstraintID: constraint.identifier)
                    self.pendingOccurrences.forEach { pending in
                        if pending.parentConstraintID == constraint.identifier {
                            occurrences.append(pending)
                        }
                    }
                    self.occurrencesMap[constraint] = occurrences
                } catch {
                    AirshipLogger.error("Failed to fetch occurrences: \(error)")
                    return nil
                }
            }
            
            return constraints
        } catch {
            AirshipLogger.error("Failed to fetch constraints: \(error)")
            return nil
        }
    }

    func createFrequencyChecker(
        _ constraints: [FrequencyConstraint]
    ) async -> FrequencyChecker {
        
        return FrequencyChecker {
            return self.isOverLimit(constraints)
        } checkAndIncrement: {
            return await self.checkAndIncrement(constraints: constraints)
        }
    }

    func isOverLimit(_ constraints: [FrequencyConstraint]) -> Bool {
        
        for constraint in constraints {
            if isConstraintOverLimit(constraint) {
                return true
            }
        }
        return false
    }

    func checkAndIncrement(
        constraints: [FrequencyConstraint]
    ) async -> Bool {
        
        if self.isOverLimit(constraints) {
            return false
        }
        
        await self.recordOccurrence(
            forConstraintIDs: constraints.compactMap{ $0.identifier }
        )
        return true
    }
    
    func isConstraintOverLimit(
        _ constraint: FrequencyConstraint
    ) -> Bool {
        
        guard let occurrences = self.occurrencesMap[constraint] else {
            return false
        }
        
        if (occurrences.count < constraint.count) {
            return false
        }
        
        let timeStamp = occurrences[occurrences.count - Int(constraint.count)].timestamp
        let timeSinceOccurrence = self.date.now.timeIntervalSince(timeStamp)
        return timeSinceOccurrence <= constraint.range
    }

    func recordOccurrence(
        forConstraintIDs constraintIDs: [String]
    ) async {
        
        let date = self.date.now
        constraintIDs.forEach { identifier in
            let occurrence = Occurrence(
                withParentConstraintID: identifier,
                timestamp: date)
            self.pendingOccurrences.append(occurrence)
            
            // Update any currently active constraints
            self.occurrencesMap.forEach { (constraint, occurrences) in
                if (identifier == constraint.identifier) {
                    var newOccurrences = occurrences
                    newOccurrences.append(occurrence)
                    self.occurrencesMap[constraint] = newOccurrences
                }
            }
        }
        await writePendingOccurrences()
        
    }
    
    func writePendingOccurrences() async {
        
        let occurrences = self.pendingOccurrences
        self.pendingOccurrences.removeAll()
        do {
            try await self.frequencyLimitStore.saveOccurrences(occurrences: occurrences)
        } catch {
            AirshipLogger.error("Unable to save occurrences: \(occurrences)")
        }
    }
    
}
