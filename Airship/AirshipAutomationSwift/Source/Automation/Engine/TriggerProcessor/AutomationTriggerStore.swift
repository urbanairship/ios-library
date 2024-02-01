/* Copyright Airship and Contributors */

import Foundation
import CoreData

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol TriggerStoreProtocol: Sendable {
    func savedTriggerState(triggerID: String) async throws -> TriggerState?
    func saveTriggerStates(states: [TriggerState]) async throws
    func removeAllTriggerStates(excluding scheduleIDs: Set<String>) async throws
    func removeTriggerStatesFor(scheduleIDs: [String]) async throws
    func removeTriggerStateFor(group: String) async throws
}

extension AutomationStore: TriggerStoreProtocol {
    func savedTriggerState(triggerID: String) async throws -> TriggerState? {
        return try await requireCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "triggerID == %@", triggerID)
            return try self.fetchState(predicate: predicate, context: context).first?.toTriggerState()
        }
    }
    
    func saveTriggerStates(states: [TriggerState]) async throws {
        
        try await requireCoreData().perform { context in
            
            let fetchBlock: (String) -> TriggerStateEntity? = { triggerID in
                let predicate = NSPredicate(format: "triggerID == %@", triggerID)
                return try? self.fetchState(predicate: predicate, context: context).first
            }
            
            for state in states {
                do {
                    var saved = fetchBlock(state.triggerID)
                    
                    if saved == nil {
                        saved = try TriggerStateEntity.create(context: context, triggerID: state.triggerID, scheduleID: state.scheduleID)
                    }
                    
                   try  saved?.update(context: context, state: state, fetcher: fetchBlock)
                } catch {
                    AirshipLogger.error("Failed to save state \(state) \(error)")
                }
            }
            
            try UACoreData.save(context)
        }
    }
    
    func removeAllTriggerStates(excluding scheduleIDs: Set<String>) async throws {
        return try await requireCoreData().perform { context in
            do {
                let predicate = NSPredicate(format: "not (scheduleID in %@)", scheduleIDs)
                try self.deleteState(predicate: predicate, context: context)
            } catch {
                AirshipLogger.error("failed to remove states for \(scheduleIDs)")
            }
        }
    }
    
    func removeTriggerStatesFor(scheduleIDs: [String]) async throws {
        return try await requireCoreData().perform { context in
            do {
                let predicate = NSPredicate(format: "scheduleID in %@", scheduleIDs)
                try self.deleteState(predicate: predicate, context: context)
            } catch {
                AirshipLogger.error("failed to remove states for \(scheduleIDs)")
            }
        }
    }
    
    func removeTriggerStateFor(group: String) async throws {
        return try await requireCoreData().perform { context in
            do {
                let predicate = NSPredicate(format: "group == %@", group)
                try self.deleteState(predicate: predicate, context: context)
            } catch {
                AirshipLogger.error("failed to remove states for \(group)")
            }
        }
    }
    
    private nonisolated func fetchState(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws -> [TriggerStateEntity] {
        let request = TriggerStateEntity.fetchRequest()
        request.includesPropertyValues = true
        request.predicate = predicate

        return try context.fetch(request)
    }
    
    private nonisolated func deleteState(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws  {
        let request: NSFetchRequest<NSFetchRequestResult> = TriggerStateEntity.fetchRequest()
        request.predicate = predicate

        if self.inMemory {
            request.includesPropertyValues = false
            let results = try context.fetch(request) as? [NSManagedObject]
            results?.forEach(context.delete)
        } else {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }

        try UACoreData.save(context)
    }
}

@objc(UATriggerStateEntity)
fileprivate class TriggerStateEntity: NSManagedObject {
    static let entityName = "UATriggerStateEntity"
    
    @nonobjc class func fetchRequest() -> NSFetchRequest<TriggerStateEntity> {
        return NSFetchRequest<TriggerStateEntity>(entityName: Self.entityName)
    }
    
    @NSManaged var count: Double
    @NSManaged var goal: Double
    @NSManaged var scheduleID: String
    @NSManaged var group: String?
    @NSManaged var triggerID: String
    @NSManaged var children: [TriggerStateEntity]
    @NSManaged var parent: TriggerStateEntity?
    
    class func create(context: NSManagedObjectContext, triggerID: String, scheduleID: String) throws -> Self {
        guard let result = NSEntityDescription.insertNewObject(
            forEntityName: Self.entityName,
            into:context) as? Self
        else {
            throw AirshipErrors.error("Failed to make schedule entity")
        }
        
        result.scheduleID = scheduleID
        result.triggerID = triggerID

        return result
    }

    func update(context: NSManagedObjectContext, state: TriggerState, fetcher: (String) -> TriggerStateEntity?) throws {
        self.count = state.count
        self.goal = state.goal
        self.group = state.group
        
        let builder: (TriggerState) throws -> TriggerStateEntity = { state in
            let result = try Self.create(context: context, triggerID: state.triggerID, scheduleID: state.scheduleID)
            result.parent = self
            return result
        }
        
        for childState in state.children {
            var child = fetcher(childState.triggerID)
            if child == nil {
                let newChild = try builder(childState)
                self.children.append(newChild)
                child = newChild
            }
            
            try child?.update(context: context, state: childState, fetcher: fetcher)
        }
    }
    
    func toTriggerState() -> TriggerState {
        return TriggerState(
            count: self.count,
            goal: self.goal,
            scheduleID: self.scheduleID,
            group: self.group,
            triggerID: self.triggerID,
            children: self.children.map({ $0.toTriggerState() }))
    }
}
