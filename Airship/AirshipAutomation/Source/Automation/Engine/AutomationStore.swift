/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement
import CoreData

@_spi(AirshipInternal) import AirshipCore

protocol TriggerStoreProtocol: Sendable {
    func getTrigger(scheduleID: String, triggerID: String) async throws -> TriggerData?
    func upsertTriggers(_ triggers: [TriggerData]) async throws
    func deleteTriggers(excludingScheduleIDs: Set<String>) async throws
    func deleteTriggers(scheduleIDs: [String]) async throws
    func deleteTriggers(scheduleID: String, triggerIDs: Set<String>) async throws
}

fileprivate protocol ScheduleStoreProtocol: Sendable {
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
    /// One-time flag recording that pre-ledger execution counts already held in
    /// the current (Swift) automation store have been backfilled into the ledger.
    /// Persisted per app key by `PreferenceDataStore`.
    private static let ledgerBackfillCompletedKey = "AirshipAutomation.ledger.backfillCompleted"

    private let coreData: UACoreData?
    private let inMemory: Bool
    private let legacyStore: LegacyAutomationStore
    private let ledgerStore: any LedgerStoreProtocol
    private let date: any AirshipDateProtocol
    private let dataStore: PreferenceDataStore
    private var migrationTask: Task<Void, any Error>?

    init(
        appKey: String,
        inMemory: Bool = false,
        ledgerStore: any LedgerStoreProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        dataStore: PreferenceDataStore? = nil
    ) {
        let modelURL = AirshipAutomationResources.bundle.url(
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
        self.ledgerStore = ledgerStore
        self.date = date
        self.dataStore = dataStore ?? PreferenceDataStore(appKey: appKey)
    }

    init(
        config: RuntimeConfig,
        ledgerStore: any LedgerStoreProtocol,
        dataStore: PreferenceDataStore,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.init(
            appKey: config.appCredentials.appKey,
            ledgerStore: ledgerStore,
            date: date,
            dataStore: dataStore
        )
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

            // Pre-18 (Objective-C) store migration: move any legacy schedules into
            // the current store and backfill their execution counts into the ledger.
            if !legacyData.isEmpty {
                let identifiers = legacyData.map { $0.scheduleData.schedule.identifier }

                let didMigrate = try await coredata.performWithResult { context -> Bool in
                    let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
                    request.includesPropertyValues = true
                    request.predicate = NSPredicate(format: "identifier in %@", identifiers)

                    guard try context.fetch(request).isEmpty else {
                        // Migration already happened, probably failed to delete before
                        return false
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

                    return true
                }

                // Only backfill on the launch that actually moved the schedules.
                // The "already migrated" path above bails before this, so re-runs
                // (e.g. a previously failed legacy delete) never duplicate events.
                // Marking the backfill complete here also prevents the current-store
                // pass below from re-recording the counts we just migrated.
                if didMigrate {
                    await self.backfillLedger(legacyData: legacyData)
                    self.markLedgerBackfillCompleted()
                }

                do {
                    try await self.legacyStore.deleteAll()
                } catch {
                    AirshipLogger.error("Failed to delete legacy store \(error)")
                }
            }

            // Post-18 (Swift) store migration: on the first launch under the ledger,
            // backfill execution counts already held in the current store so limits
            // upgraded from 18.0-20.x are not reset. Runs at most once per app.
            await self.backfillCurrentStoreIfNeeded(coreData: coredata)
        }

        try await self.migrationTask?.value
    }

    private func backfillLedger(legacyData: [LegacyScheduleData]) async {
        let events = Self.backfillLedgerEvents(
            from: legacyData,
            timestamp: self.date.now
        )

        guard !events.isEmpty else { return }

        do {
            try await self.ledgerStore.recordEvents(events)
        } catch {
            AirshipLogger.error("Failed to backfill ledger execution counts: \(error)")
        }
    }

    /// Backfills execution counts from schedules already stored in the current
    /// (Swift) store into the ledger. This covers upgrades from SDK 18.0-20.x,
    /// where schedules live in the current store and never pass through the
    /// Objective-C migration above.
    ///
    /// This runs at most once per app: the completion flag is persisted in the
    /// data store, so subsequent launches (where the current store's execution
    /// counts also include ledger-recorded executions) never double-count. It is
    /// invoked during `migrateData`, before the engine executes any schedule, so
    /// on the first ledger launch the counts captured here are purely pre-ledger.
    private func backfillCurrentStoreIfNeeded(coreData: UACoreData) async {
        guard !self.dataStore.bool(forKey: Self.ledgerBackfillCompletedKey) else {
            return
        }

        do {
            let schedules = try await coreData.performWithResult { context in
                try self.fetchSchedules(context: context)
            }

            let events = Self.backfillLedgerEvents(
                scheduleCounts: schedules.map {
                    ($0.schedule.identifier, $0.executionCount)
                },
                timestamp: self.date.now
            )

            if !events.isEmpty {
                try await self.ledgerStore.recordEvents(events)
            }

            self.markLedgerBackfillCompleted()
        } catch {
            // Leave the flag unset so the backfill is retried on the next launch.
            AirshipLogger.error(
                "Failed to backfill current store execution counts into ledger: \(error)"
            )
        }
    }

    private func markLedgerBackfillCompleted() {
        self.dataStore.setBool(true, forKey: Self.ledgerBackfillCompletedKey)
    }

    /// Builds the backfill ledger events for a set of migrating legacy schedules.
    ///
    /// Each legacy schedule with a non-zero execution count contributes a single
    /// `execution` event with `result: backfill` and `count` equal to that legacy
    /// count. Backfill events carry no `trigger_id` and are never recorded under a
    /// `shared_id`, so pre-ledger history stays scoped to the schedule and never
    /// pollutes a pooled group tally. The timestamp is the migration time — an
    /// upper bound on when those executions actually happened.
    static func backfillLedgerEvents(
        from legacyData: [LegacyScheduleData],
        timestamp: Date
    ) -> [LedgerEvent] {
        return backfillLedgerEvents(
            scheduleCounts: legacyData.map {
                ($0.scheduleData.schedule.identifier, $0.scheduleData.executionCount)
            },
            timestamp: timestamp
        )
    }

    /// Builds backfill ledger events from `(scheduleID, executionCount)` pairs.
    ///
    /// Shared by the Objective-C and current-store migration paths: each schedule
    /// with a non-zero count contributes a single scheduleID-scoped
    /// `execution`/`backfill` event, carrying no `trigger_id` or `shared_id`.
    static func backfillLedgerEvents(
        scheduleCounts: [(id: String, count: Int)],
        timestamp: Date
    ) -> [LedgerEvent] {
        return scheduleCounts.compactMap { entry in
            guard entry.count > 0 else { return nil }

            return .execution(
                LedgerEvent.Execution(
                    scheduleID: entry.id,
                    sharedID: nil,
                    triggerID: nil,
                    timestamp: timestamp,
                    count: entry.count,
                    result: .backfill,
                    cancel: nil
                )
            )
        }
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

    static let entityName: String = "UAScheduleEntity"

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
    static let entityName: String = "UATriggerEntity"

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
