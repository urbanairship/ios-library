/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageAnalyticsFactoryProtocol: Sendable {
    @MainActor
    func makeAnalytics(
        scheduleID: String,
        productID: String?,
        contactID: String?,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?,
        experimentResult: ExperimentResult?
    ) -> InAppMessageAnalyticsProtocol
}

struct InAppMessageAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol {
    let eventRecorder: InAppEventRecorder
    let impressionRecorder: AirshipMeteredUsageProtocol

    init(analytics: AnalyticsProtocol, meteredUsage: AirshipMeteredUsageProtocol) {
        self.eventRecorder = InAppEventRecorder(analytics: analytics)
        self.impressionRecorder = meteredUsage
    }

    @MainActor
    func makeAnalytics(
        scheduleID: String,
        productID: String?,
        contactID: String?,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?,
        experimentResult: ExperimentResult?
    ) -> InAppMessageAnalyticsProtocol {
        return InAppMessageAnalytics(
            scheduleID: scheduleID,
            productID: productID,
            contactID: contactID,
            message: message,
            campaigns: campaigns,
            reportingMetadata: reportingContext,
            experimentResult: experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder
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
            productID: preparedScheduleInfo.productID,
            contactID: preparedScheduleInfo.contactID,
            message: message,
            campaigns: preparedScheduleInfo.campaigns,
            reportingContext: preparedScheduleInfo.reportingContext,
            experimentResult: preparedScheduleInfo.experimentResult
        )
    }
}
