/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A prepared schedule
struct PreparedSchedule: Sendable {
    let info: PreparedScheduleInfo
    let data: PreparedScheduleData
    let frequencyChecker: (any FrequencyCheckerProtocol)?
}


/// Persisted info for a schedule that has been prepared for execution
struct PreparedScheduleInfo: Codable, Equatable {
    var scheduleID: String
    var productID: String?
    var campaigns: AirshipJSON?
    var contactID: String?
    var experimentResult: ExperimentResult?
    var reportingContext: AirshipJSON?
    var triggerSessionID: String
    var additionalAudienceCheckResult: Bool
    var priority: Int

    init(
        scheduleID: String,
        productID: String? = nil,
        campaigns: AirshipJSON? = nil,
        contactID: String? = nil,
        experimentResult: ExperimentResult? = nil,
        reportingContext: AirshipJSON? = nil,
        triggerSessionID: String,
        additionalAudienceCheckResult: Bool = true,
        priority: Int
    ) {
        self.scheduleID = scheduleID
        self.productID = productID
        self.campaigns = campaigns
        self.contactID = contactID
        self.experimentResult = experimentResult
        self.reportingContext = reportingContext
        self.triggerSessionID = triggerSessionID
        self.additionalAudienceCheckResult = additionalAudienceCheckResult
        self.priority = priority
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scheduleID = try container.decode(String.self, forKey: .scheduleID)
        self.productID = try container.decodeIfPresent(String.self, forKey: .productID)
        self.campaigns = try container.decodeIfPresent(AirshipJSON.self, forKey: .campaigns)
        self.contactID = try container.decodeIfPresent(String.self, forKey: .contactID)
        self.experimentResult = try container.decodeIfPresent(ExperimentResult.self, forKey: .experimentResult)
        self.reportingContext = try container.decodeIfPresent(AirshipJSON.self, forKey: .reportingContext)
        self.triggerSessionID = try container.decodeIfPresent(String.self, forKey: .triggerSessionID) ?? UUID().uuidString
        self.additionalAudienceCheckResult = try container.decodeIfPresent(Bool.self, forKey: .additionalAudienceCheckResult) ?? true
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    }
}

/// Prepared schedule data
enum PreparedScheduleData: Equatable {
    case inAppMessage(PreparedInAppMessageData)
    case actions(AirshipJSON)

    public static func == (lhs: PreparedScheduleData, rhs: PreparedScheduleData) -> Bool {
        switch lhs {
        case  .actions(let lhsJson):
            switch rhs {
            case .actions(let rhsJson): return lhsJson == rhsJson
            default: return false
            }
        case .inAppMessage(let lhsMessageData):
            switch rhs {
            case .inAppMessage(let rhsMessageData):
                return rhsMessageData.message == lhsMessageData.message
            default: return false
            }
        }
    }
}
