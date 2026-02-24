/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol MessageViewAnalytics: ThomasLayoutMessageAnalyticsProtocol {
}

final class DefaultMessageViewAnalytics: MessageViewAnalytics {
    private static let impressionReportInterval: TimeInterval = 30 * 60 // 30 mins
    private static let defaultProductID = "default_native_mc"
    
    private let messageID: ThomasLayoutEventMessageID
    private let productID: String
    private let reportingContext: AirshipJSON?
    private let eventRecorder: any ThomasLayoutEventRecorderProtocol
    private let eventSource: ThomasLayoutEventSource
    
    private let historyStorage: any MessageDisplayHistoryStoreProtocol
    private let displayContext: AirshipMainActorValue<ThomasLayoutEventContext.Display?>
    private let sessionID: String
    private let date: any AirshipDateProtocol
    
    private let queue: AirshipAsyncSerialQueue
    
    init(
        message: MessageCenterMessage,
        eventRecorder: any ThomasLayoutEventRecorderProtocol,
        historyStorage: any MessageDisplayHistoryStoreProtocol,
        eventSource: ThomasLayoutEventSource = .airship,
        date: any AirshipDateProtocol = AirshipDate.shared,
        sessionID: String = UUID().uuidString,
        queue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()
    ) {
        self.messageID = .airship(identifier: message.id, campaigns: nil)
        self.productID = message.productID ?? Self.defaultProductID
        self.reportingContext = message.messageReporting
        self.eventRecorder = eventRecorder
        self.eventSource = eventSource
        self.date = date
        self.historyStorage = historyStorage
        self.sessionID = sessionID
        self.displayContext = .init(nil)
        self.queue = queue
        
        queue.enqueue { [messageID = messageID.identifier, sessionID, weak self] in
            guard let history = await self?.historyStorage.get(scheduleID: messageID) else {
                return
            }
            
            await MainActor.run {
                let lastTriggerSessionId = history.lastDisplay?.triggerSessionID
                self?.displayContext.set(
                    ThomasLayoutEventContext.Display(
                        triggerSessionID: lastTriggerSessionId ?? sessionID,
                        isFirstDisplay: history.lastDisplay == nil,
                        isFirstDisplayTriggerSessionID: lastTriggerSessionId == history.lastImpression?.triggerSessionID
                    )
                )
            }
        }
    }
    
    @MainActor
    func recordEvent(_ event: any ThomasLayoutEvent, layoutContext: ThomasLayoutContext?) {
        
        let now = date.now
        
        queue.enqueue { @MainActor [weak self] in
            guard let self = self else { return }
            
            if event is ThomasLayoutDisplayEvent {
                
                var history = await self.historyStorage.get(scheduleID: messageID.identifier)
                
                if let lastDisplay = history.lastDisplay {
                    if self.sessionID != lastDisplay.triggerSessionID {
                        self.displayContext.update { value in
                            value?.isFirstDisplay = false
                            value?.isFirstDisplayTriggerSessionID = false
                        }
                    } else {
                        self.displayContext.update { value in
                            value?.isFirstDisplay = false
                        }
                    }
                }

                if (recordImpression(date: now, history: history)) {
                    history.lastImpression = MessageDisplayHistory
                        .LastImpression(
                            date: now,
                            triggerSessionID: self.sessionID
                        )
                }
                
                history.lastDisplay = MessageDisplayHistory.LastDisplay(
                    triggerSessionID: self.sessionID
                )
                
                self.historyStorage.set(history, scheduleID: messageID.identifier)
            }

            let data = ThomasLayoutEventData(
                event: event,
                context: ThomasLayoutEventContext.makeContext(
                    reportingContext: reportingContext,
                    experimentsResult: nil,
                    layoutContext: layoutContext,
                    displayContext: displayContext.value
                ),
                source: eventSource,
                messageID: messageID,
                renderedLocale: nil
            )
            
            eventRecorder.recordEvent(inAppEventData: data)
        }
    }
    
    private func shouldRecordImpression(history: MessageDisplayHistory) -> Bool {
        if
            let lastImpression = history.lastImpression,
            date.now.timeIntervalSince(lastImpression.date) < Self.impressionReportInterval {
            return false
        } else {
            return true
        }
    }
    
    private func recordImpression(date: Date, history: MessageDisplayHistory) -> Bool {
        guard shouldRecordImpression(history: history) else { return false }
        
        let event = AirshipMeteredUsageEvent(
            eventID: UUID().uuidString,
            entityID: self.messageID.identifier,
            usageType: .inAppExperienceImpression,
            product: productID,
            reportingContext: reportingContext,
            timestamp: date,
            contactID: nil
        )
        
        self.eventRecorder.recordImpressionEvent(event)

        return true
    }
}
