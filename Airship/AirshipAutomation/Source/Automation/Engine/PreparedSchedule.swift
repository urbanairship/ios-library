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

    init(
        scheduleID: String,
        productID: String? = nil,
        campaigns: AirshipJSON? = nil,
        contactID: String? = nil,
        experimentResult: ExperimentResult? = nil,
        reportingContext: AirshipJSON? = nil
    ) {
        self.scheduleID = scheduleID
        self.productID = productID
        self.campaigns = campaigns
        self.contactID = contactID
        self.experimentResult = experimentResult
        self.reportingContext = reportingContext
    }
}

/// Prepared schedule data
enum PreparedScheduleData {
    case inAppMessage(PreparedInAppMessageData)
    case actions(AirshipJSON)
}
