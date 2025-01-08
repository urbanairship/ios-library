/* Copyright Airship and Contributors */

import Foundation
import CoreData

#if canImport(AirshipCore)
import AirshipCore
#endif

actor LegacyAutomationStore {
    private let coreData: UACoreData?

    init(appKey: String, inMemory: Bool = false) {
        let modelURL = AutomationResources.bundle.url(
            forResource: "UAAutomation",
            withExtension:"momd"
        )

        self.coreData = if let modelURL = modelURL {
            UACoreData(
                name: "UAAutomation",
                modelURL: modelURL,
                inMemory: inMemory,
                stores: ["Automation-\(appKey).sqlite", "In-app-automation-\(appKey).sqlite"]
            )
        } else {
            nil
        }
    }

    var legacyScheduleData: [LegacyScheduleData] {
        get async throws {
            return try await requireCoreData().performWithNullableResult(skipIfStoreNotCreated: true) { context in
                let request: NSFetchRequest<UAScheduleData> = NSFetchRequest(entityName: "UAScheduleData")
                request.includesPropertyValues = true

                return try context.fetch(request).compactMap { entity in
                    do {
                        try entity.migrateData()
                        return try entity.convert()
                    } catch {
                        AirshipLogger.error("Failed to convert schedule \(entity) error \(error)")
                    }
                    return nil
                }
            } ?? []
        }
    }

    func deleteAll() async throws {
        try await self.requireCoreData().deleteStoresOnDisk()
    }

    private func requireCoreData() throws -> UACoreData {
        guard let coreData = coreData else {
            throw AirshipErrors.error("Failed to create core data.")
        }
        return coreData
    }
}

struct LegacyScheduleData: Equatable, Sendable {
    var scheduleData: AutomationScheduleData
    var triggerDatas: [TriggerData]
}

fileprivate enum UAScheduleDelayAppState: Int {
    case any
    case foreground
    case background
}

fileprivate enum UAScheduleState: Int {
    case idle = 0
    case timeDelayed = 5
    case waitingScheduleConditions = 1
    case preparingSchedule = 6
    case executing = 2
    case paused = 3
    case finished = 4
}

fileprivate enum UAScheduleType: UInt {
    case inAppMessage = 0
    case actions = 1
    case deferred = 2
}

@objc(UAScheduleData)
fileprivate class UAScheduleData: NSManagedObject {
    @NSManaged var identifier: String
    @NSManaged var group: String?
    @NSManaged var limit: NSNumber?
    @NSManaged var triggeredCount: NSNumber?
    @NSManaged var data: String
    @NSManaged var metadata: String?
    @NSManaged var dataVersion: NSNumber
    @NSManaged var priority: NSNumber?
    @NSManaged var triggers: Set<UAScheduleTriggerData>?
    @NSManaged var start: Date?
    @NSManaged var end: Date?
    @NSManaged var delay: UAScheduleDelayData?
    @NSManaged var executionState: NSNumber?
    @NSManaged var executionStateChangeDate: Date?
    @NSManaged var delayedExecutionDate: Date?
    @NSManaged var editGracePeriod: NSNumber?
    @NSManaged var interval: NSNumber?
    @NSManaged var type: NSNumber?
    @NSManaged var audience: String?
    @NSManaged var campaigns: NSDictionary?
    @NSManaged var reportingContext: NSDictionary?
    @NSManaged var frequencyConstraintIDs: [String]?
    @NSManaged var triggeredTime: Date?
    @NSManaged var messageType: String?
    @NSManaged var bypassHoldoutGroups: NSNumber?
    @NSManaged var isNewUserEvaluationDate: Date?
    @NSManaged var productId: String?
}

@objc(UAScheduleTriggerData)
fileprivate class UAScheduleTriggerData: NSManagedObject {
    @NSManaged var goal: NSNumber
    @NSManaged var goalProgress: NSNumber?
    @NSManaged var predicateData: Data?
    @NSManaged var type: NSNumber
    @NSManaged var schedule: UAScheduleData?
    @NSManaged var delay: UAScheduleDelayData?
    @NSManaged var start: Date?
}

@objc(UAScheduleDelayData)
fileprivate class UAScheduleDelayData: NSManagedObject {
    @NSManaged var seconds: NSNumber?
    @NSManaged var screens: String?
    @NSManaged var regionID: String?
    @NSManaged var appState: NSNumber?
    @NSManaged var schedule: UAScheduleData?
    @NSManaged var cancellationTriggers: Set<UAScheduleTriggerData>?
}

fileprivate enum UAScheduleTriggerType: Int {
    case appForeground
    case appBackground
    case regionEnter
    case regionExit
    case customEventCount
    case customEventValue
    case screen
    case appInit
    case activeSession
    case version
    case featureFlagInterracted
}


fileprivate extension UAScheduleDelayData {
    func convert(
        scheduleID: String
    ) throws -> (delay: AutomationDelay, triggerData: [TriggerData]) {

        var screens: [String]?
        let json = try AirshipJSON.from(json: self.screens)
        if json.isString, let string = json.unWrap() as? String {
            screens = [string]
        } else if json.isArray, let strings = json.unWrap() as? [String] {
            screens = strings
        }

        var appState: AutomationAppState? = nil
        if let rawValue = self.appState?.intValue, let parsed = UAScheduleDelayAppState(rawValue: rawValue) {
            appState = switch(parsed) {
            case .any: nil
            case .background: .background
            case .foreground: .foreground
            }
        }

        let cancellationTriggerData = try self.cancellationTriggers?.map { data in
            try data.convert(scheduleID: scheduleID, executionType: .delayCancellation)
        } ?? []

        let delay = AutomationDelay(
            seconds: self.seconds?.doubleValue,
            screens: screens,
            regionID: self.regionID,
            appState: appState,
            cancellationTriggers: cancellationTriggerData.map { $0.trigger }
        )

        return (delay, cancellationTriggerData.map { $0.triggerData })
    }
}

fileprivate extension UAScheduleTriggerData {
    func convert(
        scheduleID: String,
        executionType:  TriggerExecutionType
    ) throws -> (trigger: AutomationTrigger, triggerData: TriggerData) {

        let decoder = JSONDecoder()

        let predicate: JSONPredicate? = if let data = self.predicateData {
            try decoder.decode(JSONPredicate.self, from: data)
        } else {
            nil
        }

        guard let legacyType = UAScheduleTriggerType(rawValue: self.type.intValue) else {
            throw AirshipErrors.error("Invalid type \(self.type)")
        }

        let type: EventAutomationTriggerType = switch(legacyType) {
        case .appForeground: .foreground
        case .appBackground: .background
        case .regionEnter: .regionEnter
        case .regionExit: .regionExit
        case .customEventCount: .customEventCount
        case .customEventValue: .customEventValue
        case .screen: .screen
        case .appInit: .appInit
        case .activeSession: .activeSession
        case .version: .version
        case .featureFlagInterracted: .featureFlagInteraction
        }

        var trigger = EventAutomationTrigger(
            type: type,
            goal: self.goal.doubleValue,
            predicate: predicate
        )
        trigger.backfillIdentifier(executionType: executionType)
        

        let triggerData = TriggerData(
            scheduleID: scheduleID,
            triggerID: trigger.id,
            count: self.goalProgress?.doubleValue ?? 0
        )

        return (.event(trigger), triggerData)
    }
}

fileprivate extension UAScheduleData {

    struct LegacyKeys {
        static let displayType = "display_type"
        static let display = "display"
        static let audience = "audience"
        static let source = "source"
        static let duration = "duration"
    }

    func convert() throws -> LegacyScheduleData {
        guard
            let rawType = self.type?.uintValue,
            let type = UAScheduleType(rawValue: rawType)
        else {
            throw AirshipErrors.error("Failed to convert message, invalid type: \(String(describing: self.type))")
        }

        guard
            let data = self.data.data(using: .utf8)
        else {
            throw AirshipErrors.error("Unable to parse data")
        }

        let decoder = JSONDecoder()

        let scheduleData: AutomationSchedule.ScheduleData = switch(type) {
        case .inAppMessage:
                .inAppMessage(try decoder.decode(InAppMessage.self, from: data))
        case .actions:
                .actions(try decoder.decode(AirshipJSON.self, from: data))
        case .deferred:
                .deferred(try decoder.decode(DeferredAutomationData.self, from: data))
        }

        var audience: AutomationAudience?
        if let data = self.audience?.data(using: .utf8) {
            audience = try decoder.decode(AutomationAudience.self, from: data)
        }

        var editGracePeriodDays: UInt?
        if let period = self.editGracePeriod?.doubleValue {
            editGracePeriodDays = UInt(period / (24 * 60 * 60)) // convert to days
        }

        let executionTriggers = try self.triggers?.map { data in
            try data.convert(scheduleID: self.identifier, executionType: .execution)
        } ?? []

        let delayData = try self.delay?.convert(scheduleID: self.identifier)

        let schedule: AutomationSchedule = AutomationSchedule(
            identifier: self.identifier,
            data: scheduleData,
            triggers: executionTriggers.map { $0.trigger },
            created: self.isNewUserEvaluationDate,
            group: self.group,
            priority: self.priority?.intValue,
            limit: self.limit?.uintValue,
            start: self.start,
            end: self.end,
            audience: audience,
            delay: delayData?.delay,
            interval: self.interval?.doubleValue,
            bypassHoldoutGroups: self.bypassHoldoutGroups?.boolValue,
            editGracePeriodDays: editGracePeriodDays,
            metadata: try AirshipJSON.from(json: self.metadata),
            campaigns: self.campaigns == nil ? nil : try AirshipJSON.wrap(self.campaigns),
            reportingContext: self.reportingContext == nil ? nil : try AirshipJSON.wrap(self.reportingContext),
            productID: self.productId,
            frequencyConstraintIDs: self.frequencyConstraintIDs,
            messageType: self.messageType
        )

        var scheduleState: AutomationScheduleState = .idle
        if let rawValue = self.executionState?.intValue, let parsed = UAScheduleState(rawValue: rawValue) {
            scheduleState = switch(parsed) {
            case .idle: .idle
            case .timeDelayed: .prepared
            case .waitingScheduleConditions: .prepared
            case .preparingSchedule: .triggered
            case .executing: .executing
            case .paused: .paused
            case .finished: .finished
            }
        }

        var preparedInfo: PreparedScheduleInfo?
        if scheduleState == .prepared || scheduleState == .executing {
            preparedInfo = PreparedScheduleInfo(
                scheduleID: schedule.identifier,
                productID: schedule.productID,
                campaigns: schedule.campaigns,
                reportingContext: schedule.reportingContext,
                triggerSessionID: UUID().uuidString,
                priority: schedule.priority ?? 0
            )
        }

        var triggerInfo: TriggeringInfo?
        if scheduleState == .prepared || scheduleState == .executing || scheduleState == .executing {
            triggerInfo = TriggeringInfo(
                context: nil,
                date: self.triggeredTime ?? self.executionStateChangeDate ?? Date.distantPast
            )
        }

        let automationScheduleData = AutomationScheduleData(
            schedule: schedule,
            scheduleState: scheduleState,
            lastScheduleModifiedDate: AirshipDate().now,
            scheduleStateChangeDate: self.executionStateChangeDate ?? Date.distantPast,
            executionCount: self.triggeredCount?.intValue ?? 0,
            triggerInfo: triggerInfo,
            preparedScheduleInfo: preparedInfo,
            associatedData: nil,
            triggerSessionID: UUID().uuidString
        )

        return LegacyScheduleData(
            scheduleData: automationScheduleData,
            triggerDatas: (delayData?.triggerData ?? []) + executionTriggers.map { $0.triggerData }
        )
    }


    func migrateData() throws {
        let version = self.dataVersion

        if (version != 3) {
            guard var json = AirshipJSONUtils.object(self.data) as? [String: Any] else {
                return
            }
            switch(version) {
            case 0:
                try perform0To1DataMigration(json: &json)
                fallthrough
            case 1:
                try perform1To2DataMigration(json: &json)
                fallthrough
            case 2:
                try perform2To3DataMigration(json: &json)
                break
            default:
                break
            }

            self.data = try AirshipJSONUtils.string(json, options: .fragmentsAllowed)
        }

    }

    // migrate duration from milliseconds to seconds
    private func perform0To1DataMigration(json: inout [String: Any]) throws {
        guard 
            json[LegacyKeys.displayType] as? String == "banner",
            var display = json[LegacyKeys.display] as? [String: Any],
            let duration = display[LegacyKeys.duration] as? Double
        else {
            return
        }

        display[LegacyKeys.duration] = duration / 1000.0
        json[LegacyKeys.display] = display
    }

    // some remote-data schedules had their source field set incorrectly to app-defined by faulty edit code
    // this code migrates all app-defined sources to remote-data
    private func perform1To2DataMigration(json: inout [String: Any]) throws {
        if let source = json[LegacyKeys.source] as? String, source == InAppMessageSource.appDefined.rawValue {
            json[LegacyKeys.source] = InAppMessageSource.remoteData.rawValue
        }
    }

    // move scheduleData.message.audience to scheduleData.audience
    // use message ID as schedule ID
    // set the schedule type
    private func perform2To3DataMigration(json: inout [String: Any]) throws {
        if json[LegacyKeys.displayType] != nil && json[LegacyKeys.display] != nil {
            self.type = NSNumber(value: UAScheduleType.inAppMessage.rawValue)

            // Audience
            if let audience = json[LegacyKeys.audience] {
                self.audience = try AirshipJSON.wrap(audience).toString()
            }

            // If source is not app defined, set the group (message ID) as the ID
            if let source = json[LegacyKeys.source] as? String, let group = self.group {
                if source == InAppMessageSource.appDefined.rawValue {
                    self.identifier = UUID().uuidString
                } else {
                    self.identifier = group
                }
            }
        } else {
            self.type = NSNumber(value: UAScheduleType.actions.rawValue)
        }
    }
}
