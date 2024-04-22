/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A prepared schedule
struct PreparedSchedule: Sendable {
    let info: PreparedScheduleInfo
    let data: PreparedScheduleData
    let frequencyChecker: FrequencyCheckerProtocol?
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

    init(
        scheduleID: String,
        productID: String? = nil,
        campaigns: AirshipJSON? = nil,
        contactID: String? = nil,
        experimentResult: ExperimentResult? = nil,
        reportingContext: AirshipJSON? = nil,
        triggerSessionID: String
    ) {
        self.scheduleID = scheduleID
        self.productID = productID
        self.campaigns = campaigns
        self.contactID = contactID
        self.experimentResult = experimentResult
        self.reportingContext = reportingContext
        self.triggerSessionID = triggerSessionID
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
    }
}

/// Prepared schedule data
enum PreparedScheduleData {
    case inAppMessage(PreparedInAppMessageData)
    case actions(AirshipJSON)
}
