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
        reportingContext: AirshipJSON?,
        experimentResult: ExperimentResult?
    ) -> InAppMessageAnalyticsProtocol
}

struct InAppMessageAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol {
    let eventRecorder: InAppEventRecorder

    init(analytics: AnalyticsProtocol) {
        self.eventRecorder = InAppEventRecorder(analytics: analytics)
    }

    @MainActor
    func makeAnalytics(
        scheduleID: String,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?,
        experimentResult: ExperimentResult?
    ) -> InAppMessageAnalyticsProtocol {
        return InAppMessageAnalytics(
            scheduleID: scheduleID,
            message: message,
            campaigns: campaigns,
            reportingMetadata: reportingContext,
            experimentResult: experimentResult,
            eventRecorder: eventRecorder
        )
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
            reportingContext: preparedScheduleInfo.reportingContext,
            experimentResult: preparedScheduleInfo.experimentResult
        )
    }
}
