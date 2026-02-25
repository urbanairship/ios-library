/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif


/// Automation schedule
public struct AutomationSchedule: Sendable, Codable, Equatable {

    /// Schedule data
    public enum ScheduleData: Sendable, Equatable {
        /// Actions
        case actions(AirshipJSON)

        /// In-App message
        case inAppMessage(InAppMessage)

        /// Deferred
        /// NOTE: For internal use only. :nodoc:
        case deferred(DeferredAutomationData)
    }

    ///  The schedule ID.
    public let identifier: String

    /// List of triggers
    public var triggers: [AutomationTrigger]

    /// Optional schedule group. Can be used to cancel a set of schedules.
    public var group: String?

    /// Priority for determining order during simultaneous schedule processing
    public var priority: Int?

    /// Number of times the schedule can execute.
    public var limit: UInt?

    /// Start date
    public var start: Date?

    /// End date
    public var end: Date?

    /// On device automation selector
    public var audience: AutomationAudience?

    /// Compound audience. If both `audience` and `compoundAudience`, they will both
    /// be evaluated to determine if the schedule should be executed.
    public var compoundAudience: AutomationCompoundAudience?

    /// Delay after trigger and prepare steps before execution
    public var delay: AutomationDelay?

    ///  Execution interval.
    public var interval: TimeInterval?

    /// Schedule data
    public var data: ScheduleData

    /// If the schedule should bypass holdout groups or not
    public var bypassHoldoutGroups: Bool?


    /// After the schedule ends or is finished, how long to hold on to the schedule before
    /// deleting it. This is used to keep schedule state around for a period of time
    /// after the schedule finishes to allow for extending the schedule.
    public var editGracePeriodDays: UInt?

    /// internal
    let additionalAudienceCheckOverrides: AdditionalAudienceCheckOverrides?
    var metadata: AirshipJSON?
    var frequencyConstraintIDs: [String]?
    var messageType: String?
    var campaigns: AirshipJSON?
    var reportingContext: AirshipJSON?
    var productID: String?
    var minSDKVersion: String?
    var created: Date?
    var queue: String?


    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case triggers
        case created
        case group
        case metadata
        case priority
        case limit
        case start
        case end
        case audience
        case compoundAudience = "compound_audience"
        case delay
        case interval
        case campaigns
        case reportingContext = "reporting_context"
        case productID = "product_id"
        case bypassHoldoutGroups = "bypass_holdout_groups"
        case editGracePeriodDays = "edit_grace_period"
        case frequencyConstraintIDs = "frequency_constraint_ids"
        case messageType = "message_type"
        case scheduleType = "type"
        case actions
        case deferred
        case message
        case minSDKVersion = "min_sdk_version"
        case queue
        case additionalAudienceCheckOverrides = "additional_audience_check_overrides"
    }

    enum ScheduleType: String, Codable {
        case actions
        case inAppMessage = "in_app_message"
        case deferred
    }


    /// <#Description#>
    /// - Parameters:
    ///   - identifier: The schedule ID
    ///   - triggers: List of triggers for the schedule
    ///   - data: Schedule data
    ///   - group: Schedule group that can be used to cancel a set of schedules
    ///   - priority: Priority for determining order during simultaneous schedule processing
    ///   - limit: Number of times the schedule can execute
    ///   - start: Start date
    ///   - end: End date
    ///   - audience: On device automation selector
    ///   - compoundAudience: Compound automation selector
    ///   - delay: Duration after trigger and prepare steps after which execution occurs
    ///   - interval: Execution interval
    ///   - bypassHoldoutGroups: If the schedule should bypass holdout groups or not
    ///   - editGracePeriodDays: Duration after which post-execution deletion occurs
    public init(
        identifier: String,
        triggers: [AutomationTrigger],
        data: ScheduleData,
        group: String? = nil,
        priority: Int? = nil,
        limit: UInt? = nil,
        start: Date? = nil,
        end: Date? = nil,
        audience: AutomationAudience? = nil,
        compoundAudience: AutomationCompoundAudience? = nil,
        delay: AutomationDelay? = nil,
        interval: TimeInterval? = nil,
        bypassHoldoutGroups: Bool? = nil,
        editGracePeriodDays: UInt? = nil
    ) {
        self.identifier = identifier
        self.triggers = triggers
        self.created = Date()
        self.group = group
        self.priority = priority
        self.limit = limit
        self.start = start
        self.end = end
        self.audience = audience
        self.compoundAudience = compoundAudience
        self.delay = delay
        self.interval = interval
        self.data = data
        self.bypassHoldoutGroups = bypassHoldoutGroups
        self.editGracePeriodDays = editGracePeriodDays

        self.metadata = nil
        self.frequencyConstraintIDs = nil
        self.messageType = nil
        self.campaigns = nil
        self.reportingContext = nil
        self.productID = nil
        self.queue = nil
        self.additionalAudienceCheckOverrides = nil
    }

    init(
        identifier: String,
        data: ScheduleData,
        triggers: [AutomationTrigger],
        created: Date? = Date(),
        lastUpdated: Date? = nil,
        group: String? = nil,
        priority: Int? = nil,
        limit: UInt? = nil,
        start: Date? = nil,
        end: Date? = nil,
        audience: AutomationAudience? = nil,
        compoundAudience: AutomationCompoundAudience? = nil,
        delay: AutomationDelay? = nil,
        interval: TimeInterval? = nil,
        bypassHoldoutGroups: Bool? = nil,
        editGracePeriodDays: UInt? = nil,
        metadata: AirshipJSON? = nil,
        campaigns: AirshipJSON? = nil,
        reportingContext: AirshipJSON? = nil,
        productID: String? = nil,
        frequencyConstraintIDs: [String]? = nil,
        messageType: String? = nil,
        minSDKVersion: String? = nil,
        queue: String? = nil,
        additionalAudienceCheckOverrides: AdditionalAudienceCheckOverrides? = nil
    ) {
        self.identifier = identifier
        self.triggers = triggers
        self.group = group
        self.priority = priority
        self.limit = limit
        self.start = start
        self.end = end
        self.audience = audience
        self.compoundAudience = compoundAudience
        self.delay = delay
        self.interval = interval
        self.data = data
        self.bypassHoldoutGroups = bypassHoldoutGroups
        self.editGracePeriodDays = editGracePeriodDays
        self.metadata = metadata
        self.campaigns = campaigns
        self.reportingContext = reportingContext
        self.productID = productID
        self.frequencyConstraintIDs = frequencyConstraintIDs
        self.messageType = messageType
        self.created = created
        self.minSDKVersion = minSDKVersion
        self.queue = queue
        self.additionalAudienceCheckOverrides = additionalAudienceCheckOverrides
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.triggers = try container.decode([AutomationTrigger].self, forKey: .triggers)
        self.group = try container.decodeIfPresent(String.self, forKey: .group)
        self.metadata = try container.decodeIfPresent(AirshipJSON.self, forKey: .metadata)
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        self.limit = try container.decodeIfPresent(UInt.self, forKey: .limit)
        self.start = try container.decodeIfPresent(String.self, forKey: .start)?.toDate()
        self.end = try container.decodeIfPresent(String.self, forKey: .end)?.toDate()
        self.audience = try container.decodeIfPresent(AutomationAudience.self, forKey: .audience)
        self.compoundAudience = try container.decodeIfPresent(AutomationCompoundAudience.self, forKey: .compoundAudience)
        self.delay = try container.decodeIfPresent(AutomationDelay.self, forKey: .delay)
        self.interval = try container.decodeIfPresent(TimeInterval.self, forKey: .interval)
        self.campaigns = try container.decodeIfPresent(AirshipJSON.self, forKey: .campaigns)
        self.reportingContext = try container.decodeIfPresent(AirshipJSON.self, forKey: .reportingContext)
        self.productID = try container.decodeIfPresent(String.self, forKey: .productID)
        self.bypassHoldoutGroups = try container.decodeIfPresent(Bool.self, forKey: .bypassHoldoutGroups)
        self.editGracePeriodDays = try container.decodeIfPresent(UInt.self, forKey: .editGracePeriodDays)
        self.frequencyConstraintIDs = try container.decodeIfPresent([String].self, forKey: .frequencyConstraintIDs)
        self.messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
        self.minSDKVersion = try container.decodeIfPresent(String.self, forKey: .minSDKVersion)
        self.queue = try container.decodeIfPresent(String.self, forKey: .queue)
        self.additionalAudienceCheckOverrides = try container.decodeIfPresent(AdditionalAudienceCheckOverrides.self, forKey: .additionalAudienceCheckOverrides)

        let scheduleType = try container.decode(ScheduleType.self, forKey: .scheduleType)
        switch(scheduleType) {
        case .actions:
            let actions = try container.decode(AirshipJSON.self, forKey: .actions)
            self.data = .actions(actions)
        case .inAppMessage:
            let inAppMessage = try container.decode(InAppMessage.self, forKey: .message)
            self.data = .inAppMessage(inAppMessage)
        case .deferred:
            let deferred = try container.decode(DeferredAutomationData.self, forKey: .deferred)
            self.data = .deferred(deferred)
        }

        let created = try container.decodeIfPresent(String.self, forKey: .created)

        if let created = created {
            guard let date = created.toDate() else {
                throw DecodingError.typeMismatch(
                    AutomationSchedule.self,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Invalid created date string.",
                        underlyingError: nil
                    )
                )
            }
            self.created = date
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.triggers, forKey: .triggers)
        try container.encodeIfPresent(self.created?.toISOString(), forKey: .created)
        try container.encodeIfPresent(self.group, forKey: .group)
        try container.encodeIfPresent(self.metadata, forKey: .metadata)
        try container.encodeIfPresent(self.priority, forKey: .priority)
        try container.encodeIfPresent(self.limit, forKey: .limit)
        try container.encodeIfPresent(self.start?.toISOString(), forKey: .start)
        try container.encodeIfPresent(self.end?.toISOString(), forKey: .end)
        try container.encodeIfPresent(self.audience, forKey: .audience)
        try container.encodeIfPresent(self.compoundAudience, forKey: .compoundAudience)
        try container.encodeIfPresent(self.delay, forKey: .delay)
        try container.encodeIfPresent(self.interval, forKey: .interval)
        try container.encodeIfPresent(self.campaigns, forKey: .campaigns)
        try container.encodeIfPresent(self.reportingContext, forKey: .reportingContext)
        try container.encodeIfPresent(self.productID, forKey: .productID)
        try container.encodeIfPresent(self.bypassHoldoutGroups, forKey: .bypassHoldoutGroups)
        try container.encodeIfPresent(self.editGracePeriodDays, forKey: .editGracePeriodDays)
        try container.encodeIfPresent(self.frequencyConstraintIDs, forKey: .frequencyConstraintIDs)
        try container.encodeIfPresent(self.messageType, forKey: .messageType)
        try container.encodeIfPresent(self.minSDKVersion, forKey: .minSDKVersion)
        try container.encodeIfPresent(self.queue, forKey: .queue)
        try container.encodeIfPresent(self.additionalAudienceCheckOverrides, forKey: .additionalAudienceCheckOverrides)

        switch(self.data) {
        case .actions(let actions):
            try container.encode(ScheduleType.actions, forKey: .scheduleType)
            try container.encode(actions, forKey: .actions)
        case .inAppMessage(let message):
            try container.encode(ScheduleType.inAppMessage, forKey: .scheduleType)
            try container.encode(message, forKey: .message)
        case .deferred(let deferred):
            try container.encode(ScheduleType.deferred, forKey: .scheduleType)
            try container.encode(deferred, forKey: .deferred)
        }
    }
}

fileprivate extension String {
    func toDate() -> Date? {
        return AirshipDateFormatter.date(fromISOString: self)
    }
}

fileprivate extension Date {
    func toISOString() -> String {
        return AirshipDateFormatter.string(fromDate: self, format: .iso)
    }
}

extension AutomationSchedule {
    var isInAppMessageType: Bool {
        switch (data) {
        case .actions(_): return false
        case .inAppMessage(_): return true
        case .deferred(let deferred):
            switch(deferred.type) {
            case .actions: return false
            case .inAppMessage: return true
            }
        }
    }

    func isNewSchedule(sinceDate: Date, lastSDKVersion: String?) -> Bool {
        guard let created = self.created else { return false }

        if created > sinceDate {
            return true
        }

        guard let minSDKVersion = self.minSDKVersion else { return false }

        // We can skip checking if the min_sdk_version is newer than the current SDK version since
        // remote-data will filter them out. This flag is only a hint to the SDK to treat a schedule with
        // an older created timestamp as a new schedule.

        let constraint = if let lastSDKVersion = lastSDKVersion {
            "]\(lastSDKVersion),)"
        } else {
            // If we do not have a last SDK version, then we are coming from an SDK older than
            // 16.2.0. Check for a min SDK version newer or equal to 16.2.0.
            "[16.2.0,)"
        }

        guard let matcher = try? AirshipIvyVersionMatcher(versionConstraint: constraint) else { return false }
        return matcher.evaluate(version: minSDKVersion)
    }
}
