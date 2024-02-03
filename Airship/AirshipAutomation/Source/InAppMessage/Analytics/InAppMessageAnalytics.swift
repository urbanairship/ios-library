/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageAnalyticsProtocol: Sendable {
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?)
    func recordImpression() async
}

final class LoggingInAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        if let layoutContext = layoutContext {
            print("Event added: \(event) context: \(layoutContext)")
        } else {
            print("Event added: \(event)")
        }
    }
    
    func recordImpression() {
        print("Impression recorded")
    }
}

final class InAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    private let messageID: InAppEventMessageID
    private let source: InAppEventSource
    private let renderedLocale: AirshipJSON?
    private let reportingMetadata: AirshipJSON?
    private let experimentResult: ExperimentResult?
    private let eventRecorder: InAppEventRecorderProtocol
    private let impressionRecorder: AirshipMeteredUsageProtocol
    private let isReportingEnabled: Bool
    private let productID: String?
    private let contactID: String?
    private let date: AirshipDateProtocol

    init(
        scheduleID: String,
        productID: String?,
        contactID: String?,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingMetadata: AirshipJSON?,
        experimentResult: ExperimentResult?,
        eventRecorder: InAppEventRecorderProtocol,
        impressionRecorder: AirshipMeteredUsageProtocol,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.messageID = Self.makeMessageID(message: message, scheduleID: scheduleID, campaigns: campaigns)
        self.source = Self.makeEventSource(message: message)
        self.productID = productID
        self.contactID = contactID
        self.renderedLocale = message.renderedLocale
        self.reportingMetadata = reportingMetadata
        self.experimentResult = experimentResult
        self.eventRecorder = eventRecorder
        self.impressionRecorder = impressionRecorder
        self.isReportingEnabled = message.isReportingEnabled ?? true
        self.date = date
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
    
    func recordImpression() async {
        guard let productID = self.productID else { return }
        
        let impression = AirshipMeteredUsageEvent(
            eventID: UUID().uuidString,
            entityID: self.messageID.identifier,
            usageType: .inAppExperienceImpression,
            product: productID,
            reportingContext: self.reportingMetadata,
            timestamp: date.now,
            contactId: contactID)
        
        do {
            try await self.impressionRecorder.addEvent(impression)
        } catch {
            AirshipLogger.error("Failed to record impression: \(error)")
        }
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

