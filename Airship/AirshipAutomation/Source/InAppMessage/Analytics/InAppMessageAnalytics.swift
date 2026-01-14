/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppCustomEventContext: Sendable, Encodable, Equatable {
    var id: ThomasLayoutEventMessageID
    var context: ThomasLayoutEventContext?
}

protocol InAppMessageAnalyticsProtocol: ThomasLayoutMessageAnalyticsProtocol {
    @MainActor
    func makeCustomEventContext(layoutContext: ThomasLayoutContext?) -> InAppCustomEventContext?
}

final class LoggingInAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    func makeCustomEventContext(layoutContext: ThomasLayoutContext?) -> InAppCustomEventContext? {
        return nil
    }
    
    func recordEvent(_ event: any ThomasLayoutEvent, layoutContext: ThomasLayoutContext?) {
        do {
            let body = try event.data?.prettyString ?? "nil"
            let context = try layoutContext?.prettyString ?? "nil"
            AirshipLogger.debug(
                "Adding event \(event.name.reportingName):\n body: \(body),\n layoutContext: \(context)"
            )
        } catch {
            AirshipLogger.error("Failed to log event \(event): \(error)")
        }
    }
}

fileprivate extension Encodable {
    var prettyString: String? {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            return String(data: try encoder.encode(self), encoding: .utf8)
        }
    }
}


final class InAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    private let preparedScheduleInfo: PreparedScheduleInfo
    private let messageID: ThomasLayoutEventMessageID
    private let source: ThomasLayoutEventSource
    private let renderedLocale: AirshipJSON?
    private let eventRecorder: any ThomasLayoutEventRecorderProtocol
    private let isReportingEnabled: Bool
    private let date: any AirshipDateProtocol

    private let historyStore: any MessageDisplayHistoryStoreProtocol
    private let displayImpressionRule: InAppDisplayImpressionRule

    private let displayHistory: AirshipMainActorValue<MessageDisplayHistory>
    private let displayContext: AirshipMainActorValue<ThomasLayoutEventContext.Display>

    init(
        preparedScheduleInfo: PreparedScheduleInfo,
        message: InAppMessage,
        displayImpressionRule: InAppDisplayImpressionRule,
        eventRecorder: any ThomasLayoutEventRecorderProtocol,
        historyStore: any MessageDisplayHistoryStoreProtocol,
        displayHistory: MessageDisplayHistory,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.preparedScheduleInfo = preparedScheduleInfo
        self.messageID = Self.makeMessageID(
            message: message,
            scheduleID: preparedScheduleInfo.scheduleID,
            campaigns: preparedScheduleInfo.campaigns
        )
        self.source = Self.makeEventSource(message: message)
        self.renderedLocale = message.renderedLocale
        self.eventRecorder = eventRecorder
        self.isReportingEnabled = message.isReportingEnabled ?? true
        self.displayImpressionRule = displayImpressionRule
        self.historyStore = historyStore
        self.date = date

        self.displayHistory = AirshipMainActorValue(displayHistory)

        self.displayContext = AirshipMainActorValue(
            ThomasLayoutEventContext.Display(
                triggerSessionID: preparedScheduleInfo.triggerSessionID,
                isFirstDisplay: displayHistory.lastDisplay == nil,
                isFirstDisplayTriggerSessionID: preparedScheduleInfo.triggerSessionID != displayHistory.lastDisplay?.triggerSessionID
            )
        )
    }

    @MainActor
    func makeCustomEventContext(layoutContext: ThomasLayoutContext?) -> InAppCustomEventContext? {
        return InAppCustomEventContext(
            id: self.messageID,
            context: ThomasLayoutEventContext.makeContext(
                reportingContext: self.preparedScheduleInfo.reportingContext,
                experimentsResult: self.preparedScheduleInfo.experimentResult,
                layoutContext: layoutContext,
                displayContext: self.displayContext.value
            )
        )
    }

    func recordEvent(
        _ event: any ThomasLayoutEvent,
        layoutContext: ThomasLayoutContext?
    ) {
        let now = self.date.now

        if event is ThomasLayoutDisplayEvent {
            if let lastDisplay = displayHistory.value.lastDisplay {
                if self.preparedScheduleInfo.triggerSessionID == lastDisplay.triggerSessionID {
                    self.displayContext.update { value in
                        value.isFirstDisplay = false
                        value.isFirstDisplayTriggerSessionID = false
                    }
                } else {
                    self.displayContext.update { value in
                        value.isFirstDisplay = false
                    }
                }
            }

            if (recordImpression(date: now)) {
                self.displayHistory.update { value in
                    value.lastImpression = MessageDisplayHistory.LastImpression(
                        date: now,
                        triggerSessionID: self.preparedScheduleInfo.triggerSessionID
                    )
                }
            }


            self.displayHistory.update { value in
                value.lastDisplay = MessageDisplayHistory.LastDisplay(
                    triggerSessionID: self.preparedScheduleInfo.triggerSessionID
                )
            }


            self.historyStore.set(displayHistory.value, scheduleID: preparedScheduleInfo.scheduleID)
        }


        guard self.isReportingEnabled else { return }

        let data = ThomasLayoutEventData(
            event: event, 
            context: ThomasLayoutEventContext.makeContext(
                reportingContext: self.preparedScheduleInfo.reportingContext,
                experimentsResult: self.preparedScheduleInfo.experimentResult,
                layoutContext: layoutContext,
                displayContext: self.displayContext.value
            ),
            source: self.source,
            messageID: self.messageID,
            renderedLocale: self.renderedLocale
        )

        self.eventRecorder.recordEvent(inAppEventData: data)
    }

    @MainActor
    var shouldRecordImpression: Bool {
        guard
            let lastImpression = displayHistory.value.lastImpression,
            lastImpression.triggerSessionID == self.preparedScheduleInfo.triggerSessionID
        else {
            return true
        }

        switch (self.displayImpressionRule) {
        case .interval(let interval):
            return self.date.now.timeIntervalSince(lastImpression.date) >= interval
        case .once:
            return false
        }
    }

    @MainActor
    private func recordImpression(date: Date) -> Bool {
        guard shouldRecordImpression else { return false }
        guard let productID = self.preparedScheduleInfo.productID else { return false }

        let event = AirshipMeteredUsageEvent(
            eventID: UUID().uuidString,
            entityID: self.messageID.identifier,
            usageType: .inAppExperienceImpression,
            product: productID,
            reportingContext: self.preparedScheduleInfo.reportingContext,
            timestamp: date,
            contactID: self.preparedScheduleInfo.contactID
        )
        self.eventRecorder.recordImpressionEvent(event)

        return true
    }

    private static func makeMessageID(
        message: InAppMessage,
        scheduleID: String,
        campaigns: AirshipJSON?
    ) -> ThomasLayoutEventMessageID {
        switch (message.source ?? .remoteData) {
        case .appDefined: return .appDefined(identifier: scheduleID)
        case .remoteData: return .airship(identifier: scheduleID, campaigns: campaigns)
        case .legacyPush: return .legacy(identifier: scheduleID)
        }
    }

    private static func makeEventSource(
        message: InAppMessage
    ) -> ThomasLayoutEventSource {
        switch (message.source ?? .remoteData) {
        case .appDefined: return .appDefined
        case .remoteData: return .airship
        case .legacyPush: return .airship
        }
    }
}

