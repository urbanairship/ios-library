/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol MessageViewAnalytics: ThomasLayoutMessageAnalyticsProtocol {
}

final class DefaultMessageViewAnalytics: MessageViewAnalytics {
    private let messageId: ThomasLayoutEventMessageID
    private let reportingContext: AirshipJSON?
    private let eventRecorder: any ThomasLayoutEventRecorderProtocol
    private let eventSource: ThomasLayoutEventSource
    
    init(
        message: MessageCenterMessage,
        eventRecorder: any ThomasLayoutEventRecorderProtocol,
        eventSource: ThomasLayoutEventSource = .airship
    ) {
        self.messageId = .airship(identifier: message.id, campaigns: nil)
        self.reportingContext = message.messageReporting
        self.eventRecorder = eventRecorder
        self.eventSource = eventSource
    }
    
    func recordEvent(_ event: any ThomasLayoutEvent,
                     layoutContext: ThomasLayoutContext?
    ) {
        let data = ThomasLayoutEventData(
            event: event,
            context: ThomasLayoutEventContext.makeContext(
                reportingContext: reportingContext,
                experimentsResult: nil,
                layoutContext: layoutContext,
                displayContext: nil //TODO: needs to be filled
            ),
            source: eventSource,
            messageID: messageId,
            renderedLocale: nil
        )
        
        eventRecorder.recordEvent(inAppEventData: data)
    }
}
