/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageAnalyticsFactoryProtocol: Sendable {
    @MainActor
    func makeAnalytics(
        scheduleID: String,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?
    ) -> InAppMessageAnalyticsProtocol
}

struct InAppMessageAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol {
    @MainActor
    func makeAnalytics(
        scheduleID: String,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?
    ) -> InAppMessageAnalyticsProtocol {
        return InAppMessageAnalytics()
    }
}

extension InAppMessageAnalyticsFactoryProtocol {
    @MainActor
    func makeAnalytics(
        message: InAppMessage,
        preparedScheduleInfo: PreparedScheduleInfo
    ) -> InAppMessageAnalyticsProtocol {
        return self.makeAnalytics(
            scheduleID: preparedScheduleInfo.scheduleID,
            message: message,
            campaigns: preparedScheduleInfo.campaigns,
            reportingContext: preparedScheduleInfo.reportingContext
        )
    }
}
