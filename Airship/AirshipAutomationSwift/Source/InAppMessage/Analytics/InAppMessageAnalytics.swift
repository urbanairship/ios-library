/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageAnalyticsProtocol: Sendable {
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?)
}

final class LoggingInAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        if let layoutContext = layoutContext {
            print("Event added: \(event) context: \(layoutContext)")
        } else {
            print("Event added: \(event)")
        }
    }
}

final class InAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    private let messageID: InAppEventMessageID
    private let source: InAppEventSource
    private let renderedLocale: AirshipJSON?
    private let reportingMetadata: AirshipJSON?
    private let experimentResult: ExperimentResult?
    private let eventRecorder: InAppEventRecorderProtocol
    private let isReportingEnabled: Bool

    init(
        scheduleID: String,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingMetadata: AirshipJSON?,
        experimentResult: ExperimentResult?,
        eventRecorder: InAppEventRecorderProtocol
    ) {
        self.messageID = Self.makeMessageID(message: message, scheduleID: scheduleID, campaigns: campaigns)
        self.source = Self.makeEventSource(message: message)
        self.renderedLocale = message.renderedLocale
        self.reportingMetadata = reportingMetadata
        self.experimentResult = experimentResult
        self.eventRecorder = eventRecorder
        self.isReportingEnabled = message.isReportingEnabled ?? true
    }

    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        guard self.isReportingEnabled else { return }

        let data = InAppEventData(
            event: event, 
            context: InAppEventContext.makeContext(
                reportingContext: self.reportingMetadata,
                experimentsResult: self.experimentResult,
                layoutContext: layoutContext
            ),
            source: self.source,
            messageID: self.messageID,
            renderedLocale: self.renderedLocale
        )

        self.eventRecorder.recordEvent(inAppEventData: data)
    }

    private static func makeMessageID(
        message: InAppMessage,
        scheduleID: String,
        campaigns: AirshipJSON?
    ) -> InAppEventMessageID {
        switch (message.source ?? .remoteData) {
        case .appDefined: return .appDefined(identifier: scheduleID)
        case .remoteData: return .airship(identifier: scheduleID, campaigns: campaigns)
        case .legacyPush: return .legacy(identifier: scheduleID)
        }
    }

    private static func makeEventSource(
        message: InAppMessage
    ) -> InAppEventSource {
        switch (message.source ?? .remoteData) {
        case .appDefined: return .appDefined
        case .remoteData: return .airship
        case .legacyPush: return .airship
        }
    }
}

