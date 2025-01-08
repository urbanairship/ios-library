/* Copyright Airship and Contributors */

import Foundation
import CoreData

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol TriggerStoreProtocol: Sendable {
    func getTrigger(scheduleID: String, triggerID: String) async throws -> TriggerData?
    func upsertTriggers(_ triggers: [TriggerData]) async throws
    func deleteTriggers(excludingScheduleIDs: Set<String>) async throws
    func deleteTriggers(scheduleIDs: [String]) async throws
    func deleteTriggers(scheduleID: String, triggerIDs: Set<String>) async throws
}

protocol ScheduleStoreProtocol: Sendable {
    func getSchedules() async throws -> [AutomationScheduleData]

    @discardableResult
    func updateSchedule(
        scheduleID: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData?

    @discardableResult
    func updateSchedule(
        scheduleData: AutomationScheduleData,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData?

    @discardableResult
    func upsertSchedules(
        scheduleIDs: [String],
        updateBlock: @Sendable @escaping (String, AutomationScheduleData?) throws -> AutomationScheduleData
    ) async throws -> [AutomationScheduleData]

    func deleteSchedules(scheduleIDs: [String]) async throws
    func deleteSchedules(group: String) async throws

    func getSchedule(scheduleID: String) async throws -> AutomationScheduleData?
    func getSchedules(group: String) async throws -> [AutomationScheduleData]
    func getSchedules(scheduleIDs: [String]) async throws -> [AutomationScheduleData]
    func isCurrent(scheduleID: String, lastScheduleModifiedDate: Date, scheduleState: AutomationScheduleState) async throws -> Bool
}

actor AutomationStore: ScheduleStoreProtocol, TriggerStoreProtocol {
    private let coreData: UACoreData?
    private let inMemory: Bool
    private let legacyStore: LegacyAutomationStore
    private var migrationTask: Task<Void, any Error>?

    init(appKey: String, inMemory: Bool = false) {
        let modelURL = AutomationResources.bundle.url(
            forResource: "AirshipAutomation",
            withExtension:"momd"
        )

        self.coreData = if let modelURL = modelURL {
           UACoreData(
            name: "AirshipAutomation",
                modelURL: modelURL,
                inMemory: inMemory,
                stores: ["AirshipAutomation-\(appKey).sqlite"]
            )
        } else {
            nil
        }

        self.inMemory = inMemory
        self.legacyStore = LegacyAutomationStore(appKey: appKey, inMemory: inMemory)
    }

    init(config: RuntimeConfig) {
        self.init(appKey: config.appCredentials.appKey)
    }

    func getSchedules() async throws -> [AutomationScheduleData] {
        return try await prepareCoreData().performWithResult { context in
            return try self.fetchSchedules(context: context)
        }
    }

    @discardableResult
    func updateSchedule(
        scheduleID: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        return try await prepareCoreData().performWithResult { context in

            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.includesPropertyValues = true
            request.predicate = NSPredicate(format: "identifier == %@", scheduleID)

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            var data = try entity.toScheduleData()
            try block(&data)
            try entity.update(data: data)
            return data
        }
    }

    @discardableResult
    func updateSchedule(
        scheduleData: AutomationScheduleData,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        return try await prepareCoreData().performWithResult { context in

            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.includesPropertyValues = true
            request.predicate = NSPredicate(format: "identifier == %@", scheduleData.schedule.identifier)

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            var data = try entity.toScheduleData(existingData: scheduleData)
            try block(&data)
            try entity.update(data: data)
            return data
        }
    }

    @discardableResult
    func upsertSchedules(
        scheduleIDs: [String],
        updateBlock: @Sendable @escaping (String, AutomationScheduleData?) throws -> AutomationScheduleData
    ) async throws -> [AutomationScheduleData] {
        return try await prepareCoreData().performWithResult { context in
            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.includesPropertyValues = true
            request.predicate = NSPredicate(format: "identifier in %@", scheduleIDs)

            let entityMap = try context.fetch(request).reduce(into: [String: ScheduleEntity]()) {
                $0[$1.identifier] = $1
            }

            var result: [AutomationScheduleData] = []

            for identifier in scheduleIDs {
                let existing: AutomationScheduleData? = if let entity = entityMap[identifier] {
                    try entity.toScheduleData()
                } else {
                    nil
                }
                let data = try updateBlock(identifier, existing)
                let entity = try (entityMap[identifier] ?? ScheduleEntity.make(context: context))

                try entity.update(data: data)
                result.append(data)
            }
            return result
        }
    }

    func deleteSchedules(scheduleIDs: [String]) async throws {
        return try await prepareCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier in %@", scheduleIDs)
            return try self.deleteSchedules(predicate: predicate, context: context)
        }
    }

    func deleteSchedules(group: String) async throws {
        return try await prepareCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "group == %@", group)
            return try self.deleteSchedules(predicate: predicate, context: context)
        }
    }

    func isCurrent(scheduleID: String, lastScheduleModifiedDate: Date, scheduleState: AutomationScheduleState) async throws -> Bool {
        return try await prepareCoreData().performWithResult { context in
            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.predicate = NSPredicate(format: "identifier == %@", scheduleID)
            request.propertiesToFetch = ["lastScheduleModifiedDate", "scheduleState"]
            request.includesPropertyValues = true

            let entity = try context.fetch(request).first
            return entity?.lastScheduleModifiedDate == lastScheduleModifiedDate &&  entity?.scheduleState == scheduleState.rawValue
        }
    }

    func getSchedule(scheduleID: String) async throws -> AutomationScheduleData? {
        return try await prepareCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier == %@", scheduleID)
            return try self.fetchSchedules(predicate: predicate, context: context).first
        }
    }

    func getAssociatedData(scheduleID: String) async throws -> Data? {
        return try await prepareCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier == %@", scheduleID)

            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.includesPropertyValues = true
            request.predicate = predicate

            return try context.fetch(request).first?.associatedData
        }
    }

    func getSchedules(group: String) async throws -> [AutomationScheduleData] {
        return try await prepareCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "group == %@", group)
            return try self.fetchSchedules(predicate: predicate, context: context)
        }
    }

    func getSchedules(scheduleIDs: [String]) async throws -> [AutomationScheduleData] {
        return try await prepareCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier in %@", scheduleIDs)
            return try self.fetchSchedules(predicate: predicate, context: context)
        }
    }

    func getTrigger(scheduleID: String, triggerID: String) async throws -> TriggerData? {
        return try await prepareCoreData().performWithResult { context in
            let request: NSFetchRequest<TriggerEntity> = TriggerEntity.fetchRequest()
            request.predicate = NSPredicate(format: "scheduleID == %@ AND triggerID == %@", scheduleID, triggerID)
            return try context.fetch(request).first?.toTriggerData()
        }
    }

    func upsertTriggers(_ triggers: [TriggerData]) async throws {
        guard !triggers.isEmpty else { return }
        
        let groupedTriggers = triggers.reduce(into: [String: [TriggerData]]()) { result, trigger in
            var array = result[trigger.scheduleID] ?? []
            array.append(trigger)
            result[trigger.scheduleID] = array
        }
        
        try await prepareCoreData().perform { context in
            let request: NSFetchRequest<TriggerEntity> = TriggerEntity.fetchRequest()
            
            try groupedTriggers.forEach { scheduleID, triggers in
                request.predicate = NSPredicate(format: "scheduleID == %@ AND triggerID in %@", scheduleID, triggers.map { $0.triggerID })

                let entityMap = try context.fetch(request).reduce(into: [String: TriggerEntity]()) {
                    $0[$1.triggerID] = $1
                }

                for trigger in triggers {
                    let entity = try (entityMap[trigger.triggerID] ?? TriggerEntity.make(context: context))
                    try entity.update(data: trigger)
                }
            }
        }
    }

    func deleteTriggers(scheduleID: String, triggerIDs: Set<String>) async throws {
        return try await prepareCoreData().perform { context in
            let predicate = NSPredicate(format: "(scheduleID == %@) AND (triggerID in %@)", scheduleID, triggerIDs)
            try self.deleteTriggers(predicate: predicate, context: context)
        }
    }

    func deleteTriggers(excludingScheduleIDs: Set<String>) async throws {
        return try await prepareCoreData().perform { context in
            let predicate = NSPredicate(format: "not (scheduleID in %@)", excludingScheduleIDs)
            try self.deleteTriggers(predicate: predicate, context: context)
        }
    }

    func deleteTriggers(scheduleIDs: [String]) async throws {
        try await prepareCoreData().perform { context in
            let predicate = NSPredicate(format: "scheduleID in %@", scheduleIDs)
            try self.deleteTriggers(predicate: predicate, context: context)
        }
    }

    private nonisolated func deleteTriggers(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws  {
        let request: NSFetchRequest<any NSFetchRequestResult> = TriggerEntity.fetchRequest()
        request.predicate = predicate

        if self.inMemory {
            request.includesPropertyValues = false
            let results = try context.fetch(request) as? [NSManagedObject]
            results?.forEach(context.delete)
        } else {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }

    private nonisolated func fetchSchedules(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws -> [AutomationScheduleData] {
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        request.includesPropertyValues = true
        request.predicate = predicate

        return try context.fetch(request).map { entity in
            try entity.toScheduleData()
        }
    }

    private nonisolated func deleteSchedules(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws  {
        let request = NSFetchRequest<any NSFetchRequestResult>(
            entityName: ScheduleEntity.entityName
        )
        request.predicate = predicate

        if self.inMemory {
            request.includesPropertyValues = false
            let schedules = try context.fetch(request) as? [NSManagedObject]
            schedules?.forEach { schedule in
                context.delete(schedule)
            }
        } else {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }

    private func migrateData() async throws {
        guard let coredata = self.coreData else {
            throw AirshipErrors.error("Failed to create core data.")
        }
        do {
            if let migrationTask = migrationTask {
                try await migrationTask.value
                return
            }
        } catch {}

        self.migrationTask = Task {
            let legacyData = try await self.legacyStore.legacyScheduleData
            guard !legacyData.isEmpty else { return }

            let identifiers = legacyData.map { $0.scheduleData.schedule.identifier }

            try await coredata.perform { context in
                let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
                request.includesPropertyValues = true
                request.predicate = NSPredicate(format: "identifier in %@", identifiers)

                guard try context.fetch(request).isEmpty else {
                    // Migration already happened, probably failed to delete before
                    return
                }

                do {
                    for legacy in legacyData {
                        let scheduleEntity = try ScheduleEntity.make(context: context)
                        try scheduleEntity.update(data: legacy.scheduleData)

                        for triggerData in legacy.triggerDatas {
                            let triggerEntity = try TriggerEntity.make(context: context)
                            try triggerEntity.update(data: triggerData)
                        }
                    }
                } catch {
                    context.rollback()
                    throw error
                }
            }

            do {
                try await self.legacyStore.deleteAll()
            } catch {
                AirshipLogger.error("Failed to delete legacy store \(error)")
            }
        }

        try await self.migrationTask?.value
    }

    func prepareCoreData() async throws -> UACoreData {
        guard let coreData = coreData else {
            throw AirshipErrors.error("Failed to create core data.")
        }

        try await migrateData()
        return coreData
    }
}


@objc(UAScheduleEntity)
fileprivate class ScheduleEntity: NSManagedObject {

    static let entityName = "UAScheduleEntity"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: ScheduleEntity.entityName)
    }

    @NSManaged var identifier: String
    @NSManaged var group: String?
    @NSManaged var schedule: Data
    @NSManaged var scheduleState: String
    @NSManaged var scheduleStateChangeDate: Date
    @NSManaged var lastScheduleModifiedDate: Date?
    @NSManaged var executionCount: Int
    @NSManaged var triggerInfo: Data?
    @NSManaged var preparedScheduleInfo: Data?
    @NSManaged var triggerSessionID: String?
    @NSManaged var associatedData: Data?

    class func make(context: NSManagedObjectContext) throws -> Self {
        guard let data = NSEntityDescription.insertNewObject(
            forEntityName: ScheduleEntity.entityName,
            into:context) as? Self
        else {
            throw AirshipErrors.error("Failed to make schedule entity")
        }

        return data
    }

    func update(data: AutomationScheduleData) throws {
        let encoder = JSONEncoder()
        self.identifier = data.schedule.identifier
        self.group = data.schedule.group
        self.scheduleState = data.scheduleState.rawValue
        self.scheduleStateChangeDate = data.scheduleStateChangeDate
        self.executionCount = data.executionCount
        self.triggerSessionID = data.triggerSessionID
        self.associatedData = data.associatedData
        self.lastScheduleModifiedDate = data.lastScheduleModifiedDate
        self.schedule = try encoder.encode(data.schedule)

        self.preparedScheduleInfo = if let info = data.preparedScheduleInfo {
            try encoder.encode(info)
        } else {
            nil
        }

        self.triggerInfo = if let info = data.triggerInfo {
            try encoder.encode(info)
        } else {
            nil
        }

    }

    func toScheduleData(existingData: AutomationScheduleData? = nil) throws -> AutomationScheduleData {
        let decoder = JSONDecoder()
        let existingScheduleMatch = existingData?.scheduleStateChangeDate == self.scheduleStateChangeDate
        let schedule: AutomationSchedule = if let existingData, existingScheduleMatch {
            existingData.schedule
        } else {
            try decoder.decode(AutomationSchedule.self, from: self.schedule)
        }

        let triggerInfo: TriggeringInfo? = if let data = self.triggerInfo {
            try decoder.decode(TriggeringInfo.self, from: data)
        } else {
            nil
        }

        let preparedScheduleInfo: PreparedScheduleInfo? = if let data = self.preparedScheduleInfo {
            try decoder.decode(PreparedScheduleInfo.self, from: data)
        } else {
            nil
        }

        guard let scheduleState = AutomationScheduleState(rawValue: self.scheduleState) else {
            throw AirshipErrors.error("Invalid schedule state \(self.scheduleState)")
        }

        return AutomationScheduleData(
            schedule: schedule,
            scheduleState: scheduleState,
            lastScheduleModifiedDate: self.lastScheduleModifiedDate ?? .distantPast,
            scheduleStateChangeDate: self.scheduleStateChangeDate,
            executionCount: executionCount,
            triggerInfo: triggerInfo,
            preparedScheduleInfo: preparedScheduleInfo,
            associatedData: associatedData,
            triggerSessionID: self.triggerSessionID ?? UUID().uuidString
        )
    }
}


@objc(UATriggerEntity)
fileprivate class TriggerEntity: NSManagedObject {
    static let entityName = "UATriggerEntity"

    @nonobjc class func fetchRequest() -> NSFetchRequest<TriggerEntity> {
        return NSFetchRequest<TriggerEntity>(entityName: Self.entityName)
    }

    @NSManaged var state: Data
    @NSManaged var scheduleID: String
    @NSManaged var triggerID: String

    class func make(context: NSManagedObjectContext) throws -> Self {
        guard let result = NSEntityDescription.insertNewObject(
            forEntityName: Self.entityName,
            into:context) as? Self
        else {
            throw AirshipErrors.error("Failed to make schedule entity")
        }

        return result
    }

    func update(data: TriggerData) throws {
        self.triggerID = data.triggerID
        self.scheduleID = data.scheduleID
        self.state = try JSONEncoder().encode(data)
    }

    func toTriggerData() throws -> TriggerData {
        try JSONDecoder().decode(TriggerData.self, from: self.state)
    }
}
