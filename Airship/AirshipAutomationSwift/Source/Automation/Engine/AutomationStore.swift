/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


actor AutomationStore {

    private let coreData: UACoreData?
    let inMemory: Bool

    init(appKey: String, inMemory: Bool = false) {
        let bundle = AutomationResources.bundle
        self.inMemory = inMemory
        if let modelURL = bundle.url(forResource: "AirshipAutomation", withExtension:"momd") {
            self.coreData = UACoreData(
                modelURL: modelURL,
                inMemory: inMemory,
                stores: ["AirshipAutomation-\(appKey).sqlite"]
            )
        } else {
            self.coreData = nil
        }
    }

    init(config: RuntimeConfig) {
        self.init(appKey: config.appKey)
    }

    var schedules: [AutomationScheduleData] {
        get async throws {
            return try await requireCoreData().performWithResult { context in
                return try self.fetchSchedules(context: context)
            }
        }
    }

    @discardableResult
    func update(
        identifier: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        return try await requireCoreData().performWithResult { context in
            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.includesPropertyValues = true
            request.predicate = NSPredicate(format: "identifier == %@", identifier)

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            var data = try AutomationScheduleData.fromEntity(entity)
            try block(&data)
            try entity.update(data: data)
            try UACoreData.save(context)
            return data
        }
    }

    func batchUpsert(
        identifiers: [String],
        updateBlock: @Sendable @escaping (String, AutomationScheduleData?) throws -> AutomationScheduleData
    ) async throws -> [AutomationScheduleData] {
        return try await requireCoreData().performWithResult { context in
            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.includesPropertyValues = true
            request.predicate = NSPredicate(format: "identifier in %@", identifiers)

            let entityMap = try context.fetch(request).reduce(into: [String: ScheduleEntity]()) {
                $0[$1.identifier] = $1
            }

            var result: [AutomationScheduleData] = []

            for identifier in identifiers {
                let existing: AutomationScheduleData? = if let entity = entityMap[identifier] {
                    try AutomationScheduleData.fromEntity(entity)
                } else {
                    nil
                }
                let data = try updateBlock(identifier, existing)
                let entity = try (entityMap[identifier] ?? self.makeScheduleEntity(context: context))
                try entity.update(data: data)
                result.append(data)
            }
            try UACoreData.save(context)
            return result
        }
    }

    func delete(identifiers: [String]) async throws {
        return try await requireCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier in %@", identifiers)
            return try self.deleteSchedules(predicate: predicate, context: context)
        }
    }

    func delete(group: String) async throws {
        return try await requireCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "group == %@", group)
            return try self.deleteSchedules(predicate: predicate, context: context)
        }
    }

    func getSchedule(identifier: String) async throws -> AutomationScheduleData? {
        return try await requireCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier == %@", identifier)
            return try self.fetchSchedules(predicate: predicate, context: context).first
        }
    }

    func getSchedules(group: String) async throws -> [AutomationScheduleData] {
        return try await requireCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "group == %@", group)
            return try self.fetchSchedules(predicate: predicate, context: context)
        }
    }

    func getSchedules(identifiers: [String]) async throws -> [AutomationScheduleData] {
        return try await requireCoreData().performWithResult { context in
            let predicate = NSPredicate(format: "identifier in %@", identifiers)
            return try self.fetchSchedules(predicate: predicate, context: context)
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
            try AutomationScheduleData.fromEntity(entity)
        }
    }

    private nonisolated func makeScheduleEntity(
        context: NSManagedObjectContext
    ) throws -> ScheduleEntity {
        guard let data = NSEntityDescription.insertNewObject(
            forEntityName: ScheduleEntity.entityName,
            into:context) as? ScheduleEntity
        else {
            throw AirshipErrors.error("Failed to make schedule entity")
        }

        return data
    }

    private nonisolated func deleteSchedules(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) throws  {
        let request = NSFetchRequest<NSFetchRequestResult>(
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

        try UACoreData.save(context)
    }


    func requireCoreData() throws -> UACoreData {
        guard let coreData = coreData else {
            throw AirshipErrors.error("Failed to create core data.")
        }
        return coreData
    }
    
}

import CoreData

@objc(UAScheduleEntity)
fileprivate class ScheduleEntity: NSManagedObject {

    static let entityName = "UAScheduleEntity"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: ScheduleEntity.entityName)
    }

    @NSManaged var identifier: String
    @NSManaged var group: String?
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var schedule: Data

    @NSManaged var scheduleState: String
    @NSManaged var scheduleStateChangeDate: Date
    @NSManaged var executionCount: UInt
    @NSManaged var triggerInfo: Data?
    @NSManaged var preparedScheduleInfo: Data?

    func update(data: AutomationScheduleData) throws {
        self.identifier = data.identifier
        self.group = data.group
        self.startDate = data.startDate
        self.endDate = data.endDate
        self.scheduleState = data.scheduleState.rawValue
        self.scheduleStateChangeDate = data.scheduleStateChangeDate
        self.executionCount = data.executionCount

        self.schedule = try AirshipJSON.defaultEncoder.encode(data.schedule)

        self.preparedScheduleInfo = if let info = data.preparedScheduleInfo {
            try AirshipJSON.defaultEncoder.encode(info)
        } else {
            nil
        }

        self.triggerInfo = if let info = data.triggerInfo {
            try AirshipJSON.defaultEncoder.encode(info)
        } else {
            nil
        }
    }
}


fileprivate extension AutomationScheduleData {
    static func fromEntity(_ entity: ScheduleEntity) throws -> AutomationScheduleData {
        let schedule = try AirshipJSON.defaultDecoder.decode(AutomationSchedule.self, from: entity.schedule)
        let triggerInfo: TriggeringInfo? = if let data = entity.triggerInfo {
            try AirshipJSON.defaultDecoder.decode(TriggeringInfo.self, from: data)
        } else {
            nil
        }

        let preparedScheduleInfo: PreparedScheduleInfo? = if let data = entity.preparedScheduleInfo {
            try AirshipJSON.defaultDecoder.decode(PreparedScheduleInfo.self, from: data)
        } else {
            nil
        }

        guard let scheduleState = AutomationScheduleState(rawValue: entity.scheduleState) else {
            throw AirshipErrors.error("Invalid schedule state \(entity.scheduleState)")
        }

        return AutomationScheduleData(
            identifier: entity.identifier,
            group: entity.group,
            startDate: entity.startDate,
            endDate: entity.endDate,
            schedule: schedule,
            scheduleState: scheduleState,
            scheduleStateChangeDate: entity.scheduleStateChangeDate,
            triggerInfo: triggerInfo,
            preparedScheduleInfo: preparedScheduleInfo
        )
    }
}
