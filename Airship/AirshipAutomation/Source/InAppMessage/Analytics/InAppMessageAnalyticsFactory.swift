/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageAnalyticsFactoryProtocol: Sendable {
    func makeAnalytics(
        preparedScheduleInfo: PreparedScheduleInfo,
        message: InAppMessage
    ) async -> any InAppMessageAnalyticsProtocol
}

struct InAppMessageAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol {
    private let eventRecorder: InAppEventRecorder
    private let displayHistoryStore: any MessageDisplayHistoryStoreProtocol
    private let displayImpressionRuleProvider: any InAppDisplayImpressionRuleProvider

    init(
        eventRecorder: InAppEventRecorder,
        displayHistoryStore: any MessageDisplayHistoryStoreProtocol,
        displayImpressionRuleProvider: any InAppDisplayImpressionRuleProvider
    ) {
        self.eventRecorder = eventRecorder
        self.displayHistoryStore = displayHistoryStore
        self.displayImpressionRuleProvider = displayImpressionRuleProvider
    }

    func makeAnalytics(
        preparedScheduleInfo: PreparedScheduleInfo,
        message: InAppMessage
    ) async -> any InAppMessageAnalyticsProtocol {
        return InAppMessageAnalytics(
            preparedScheduleInfo: preparedScheduleInfo,
            message: message,
            displayImpressionRule: displayImpressionRuleProvider.impressionRules(
                for: message
            ),
            eventRecorder: eventRecorder,
            historyStore: displayHistoryStore,
            displayHistory: await self.displayHistoryStore.get(
                scheduleID: preparedScheduleInfo.scheduleID
            )
        )
    }
}
