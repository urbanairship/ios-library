/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
@testable import AirshipMessageCenter

struct DefaultMessageViewAnalyticsTests {

    let mockRecorder = MockThomasLayoutEventRecorder()
    let historyStorage = MockDispalyHistoryStorage()
    let clock = UATestDate(offset: 0, dateOverride: Date(timeIntervalSince1970: 0))
    let operationsQueue = AirshipAsyncSerialQueue()
    let mockEvent = ThomasLayoutFormDisplayEvent(data: .init(identifier: "test", formType: "test"))

    @Test("Record event captures correct data with default Airship source")
    @MainActor
    func recordEventDefaults() async throws {
        
        let messageID = "test-message-id"
        let reportingContext = ["test": AirshipJSON.string("reporting")]
        let message = createStubMessage(id: messageID, reporting: reportingContext)
        
        let analytics = makeAnalytics(message: message)
        
        let layoutContext = ThomasLayoutContext()

        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: layoutContext)
        await operationsQueue.waitForCurrentOperations()

        let capturedData = try #require(mockRecorder.lastCapturedData, "No event data was captured")

        #expect(capturedData.event is ThomasLayoutDisplayEvent)
        #expect(capturedData.source == .airship)
        if case .airship(let identifier, let campaigns) = capturedData.messageID {
            #expect(identifier == messageID)
            #expect(campaigns == nil)
        } else {
            Issue.record("Message ID should be of type .airship")
        }
        
        let expectedReporting = try! AirshipJSON.wrap(reportingContext)
        #expect(capturedData.context!.reportingContext == expectedReporting)
    }
    
    @Test("Record events with no saved history")
    @MainActor
    func recordEventNoHistory() async throws {
        
        let messageID = "test-message-id"
        let message = createStubMessage(id: messageID)
        
        let analytics = makeAnalytics(message: message)
        
        let layoutContext = ThomasLayoutContext()
        analytics.recordEvent(mockEvent, layoutContext: layoutContext)
        await operationsQueue.waitForCurrentOperations()

        let capturedData = try #require(mockRecorder.lastCapturedData, "No event data was captured")
        #expect(capturedData.context?.display?.isFirstDisplay == true)
        #expect(capturedData.context?.display?.isFirstDisplayTriggerSessionID == true)
        
    }
    
    @Test("Record event with saved history from previous session")
    @MainActor
    func recordEventWithPreviousSession() async throws {
        let messageID = "test-message-id"
        
        let message = createStubMessage(id: messageID)
        
        let analytics = makeAnalytics(message: message, sessionID: "current-session")
        
        let layoutContext = ThomasLayoutContext()
        self.historyStorage.currentValue = MessageDisplayHistory(
            lastImpression: .init(date: clock.now.advanced(by: -100), triggerSessionID: "impression-session"),
            lastDisplay: .init(triggerSessionID: "previous-session")
        )
        analytics.recordEvent(mockEvent, layoutContext: layoutContext)
        await operationsQueue.waitForCurrentOperations()
        
        let capturedData = try #require(mockRecorder.lastCapturedData, "No event data was captured")
        #expect(capturedData.context?.display?.isFirstDisplay == false)
        #expect(capturedData.context?.display?.isFirstDisplayTriggerSessionID == false)
    }
    
    @Test("Record event with history same session")
    @MainActor
    func recordEventWithHistorySameSession() async throws {
        let messageID = "test-message-id"
        
        let message = createStubMessage(id: messageID)
        let analytics = makeAnalytics(message: message, sessionID: "current-session")
        let layoutContext = ThomasLayoutContext()
        
        self.historyStorage.currentValue = MessageDisplayHistory(
            lastImpression: .init(date: clock.now.advanced(by: -100), triggerSessionID: "last-session"),
            lastDisplay: .init(triggerSessionID: "last-session")
        )
        analytics.recordEvent(mockEvent, layoutContext: layoutContext)
        await operationsQueue.waitForCurrentOperations()
        
        let capturedData = try #require(mockRecorder.lastCapturedData, "No event data was captured")
        #expect(capturedData.context?.display?.isFirstDisplay == false)
        #expect(capturedData.context?.display?.isFirstDisplayTriggerSessionID == true)
    }
    
    @Test("Record generic event")
    @MainActor
    func recordGenericEvent() async throws {
        let messageID = "test-message-id"
        
        let message = createStubMessage(id: messageID)
        let analytics = makeAnalytics(message: message, sessionID: "current-session")
        let layoutContext = ThomasLayoutContext()
        
        analytics.recordEvent(mockEvent, layoutContext: layoutContext)
        await operationsQueue.waitForCurrentOperations()
        
        #expect(mockRecorder.events.count == 1)
        #expect(mockRecorder.impressions.isEmpty)
        #expect(historyStorage.getCalls(for: .get) == 1)
        #expect(historyStorage.getCalls(for: .set) == 0)
    }
    
    @Test("Record record first impression")
    @MainActor
    func recordFirstImpression() async throws {
        let messageID = "test-message-id"
        
        let message = createStubMessage(
            id: messageID,
            reporting: ["test": "reporting"],
            productID: "product-id"
        )
        let analytics = makeAnalytics(message: message, sessionID: "current-session")
        let layoutContext = ThomasLayoutContext()
        
        clock.offset = 100
        
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: layoutContext)
        await operationsQueue.waitForCurrentOperations()
        
        let impression = try #require(mockRecorder.lastRecordedImpression)
        #expect(impression.entityID == messageID)
        #expect(impression.usageType == .inAppExperienceImpression)
        #expect(impression.reportingContext == .object(["test": .string("reporting")]))
        #expect(impression.product == "product-id")
        #expect(impression.timestamp == clock.now)
        
        let history = try #require(historyStorage.currentValue)
        #expect(history.lastImpression?.date == clock.now)
        #expect(history.lastImpression?.triggerSessionID == "current-session")
        #expect(history.lastDisplay?.triggerSessionID == "current-session")
        
    }

    @Test("Record native message impression uses default product ID")
    @MainActor
    func recordNativeFirstImpressionUsesDefaultProductID() async throws {
        let messageID = "test-native-message-id"

        let message = createStubMessage(
            id: messageID,
            reporting: ["test": "reporting"],
            contentType: .native(version: 1)
        )
        let analytics = makeAnalytics(message: message, sessionID: "current-session")

        clock.offset = 100
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: ThomasLayoutContext())
        await operationsQueue.waitForCurrentOperations()

        let impression = try #require(mockRecorder.lastRecordedImpression)
        #expect(impression.entityID == messageID)
        #expect(impression.usageType == .inAppExperienceImpression)
        #expect(impression.reportingContext == .object(["test": .string("reporting")]))
        #expect(impression.product == "default_native_mc")
        #expect(impression.timestamp == clock.now)
    }
    
    @Test("Record impression timeout")
    @MainActor
    func recordImpressionTimeout() async throws {
        let messageID = "test-message-id"
        
        let message = createStubMessage(id: messageID)
        let analytics = makeAnalytics(message: message, sessionID: "current-session")
        
        clock.offset = 100
        let impression = MessageDisplayHistory.LastImpression(date: clock.now, triggerSessionID: "other-session")
        historyStorage.currentValue = MessageDisplayHistory(
            lastImpression: impression
        )
        
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        await operationsQueue.waitForCurrentOperations()
        #expect(mockRecorder.lastRecordedImpression == nil)
        #expect(historyStorage.currentValue?.lastImpression == impression)
        #expect(historyStorage.currentValue?.lastDisplay?.triggerSessionID == "current-session")
        
        clock.offset += 30 * 60 - 1
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        await operationsQueue.waitForCurrentOperations()
        #expect(mockRecorder.lastRecordedImpression == nil)
        #expect(historyStorage.currentValue?.lastImpression == impression)
        #expect(historyStorage.currentValue?.lastDisplay?.triggerSessionID == "current-session")
        
        clock.offset += 1
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        await operationsQueue.waitForCurrentOperations()
        #expect(mockRecorder.lastRecordedImpression != nil)
        #expect(historyStorage.currentValue?.lastImpression?.date == clock.now)
        #expect(historyStorage.currentValue?.lastDisplay?.triggerSessionID == "current-session")
    }
    
    @Test("Impression updates display context")
    @MainActor
    func impressionUpdatesDisplayContext() async throws {
        let messageID = "test-message-id"
        
        let message = createStubMessage(id: messageID)
        let analytics = makeAnalytics(message: message, sessionID: "current-session")
        await operationsQueue.waitForCurrentOperations()
        
        clock.offset = 100
        
        #expect(mockRecorder.events.count == 0)
        #expect(historyStorage.getCalls(for: .set) == 0)
        
        //first event
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        await operationsQueue.waitForCurrentOperations()
        
        #expect(mockRecorder.events.count == 1)
        #expect(historyStorage.getCalls(for: .set) == 1)
        #expect(mockRecorder.lastRecordedImpression != nil)
        #expect(mockRecorder.lastCapturedData?.context?.display?.isFirstDisplay == true)
        
        //second event
        clock.offset += 100
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        await operationsQueue.waitForCurrentOperations()
        #expect(mockRecorder.events.count == 2)
        #expect(mockRecorder.impressions.count == 1)
        #expect(mockRecorder.lastCapturedData?.context?.display?.isFirstDisplay == false)
        #expect(historyStorage.getCalls(for: .set) == 2)
        
    }
    
    // MARK: - Helpers
    private func createStubMessage(
        id: String,
        reporting: [String: Any]? = nil,
        productID: String? = nil,
        contentType: MessageCenterMessage.ContentType = .html
    ) -> MessageCenterMessage {
        var rawMessageObject: [String: Any] = [:]
        if let productID {
            rawMessageObject["product_id"] = productID
        }
        
        return MessageCenterMessage(
            title: "Test Title",
            id: id,
            contentType: contentType,
            extra: [:],
            bodyURL: .init(string: "https://test.url")!,
            expirationDate: nil,
            messageReporting: reporting,
            unread: true,
            sentDate: Date(),
            messageURL: .init(string: "https://test.url")!,
            rawMessageObject: rawMessageObject
        )
    }
    
    private func makeAnalytics(
        message: MessageCenterMessage,
        sessionID: String = "test-session-id"
    ) -> DefaultMessageViewAnalytics {
        return DefaultMessageViewAnalytics(
            message: message,
            eventRecorder: mockRecorder,
            historyStorage: historyStorage,
            date: clock,
            sessionID: sessionID,
            queue: operationsQueue
        )
    }
}

final class MockThomasLayoutEventRecorder: ThomasLayoutEventRecorderProtocol, @unchecked Sendable {
    private(set) var lastRecordedImpression: AirshipMeteredUsageEvent? = nil
    private(set) var impressions: [AirshipMeteredUsageEvent] = []
    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent) {
        lastRecordedImpression = event
        impressions.append(event)
    }
    
    private(set) var lastCapturedData: ThomasLayoutEventData? = nil
    private(set) var events: [ThomasLayoutEventData] = []
    func recordEvent(inAppEventData: ThomasLayoutEventData) {
        lastCapturedData = inAppEventData
        events.append(inAppEventData)
    }
}

final class MockDispalyHistoryStorage: MessageDisplayHistoryStoreProtocol, @unchecked Sendable {
    enum CallType {
        case get, set
    }
    
    var currentValue: MessageDisplayHistory? = MessageDisplayHistory()
    private var recordedCalls: [CallType: Int] = [:]
    
    func getCalls(for callType: CallType) -> Int {
        recordedCalls[callType, default: 0]
    }
    
    func set(_ history: MessageDisplayHistory, scheduleID: String) {
        currentValue = history
        recordedCalls[.set, default: 0] += 1
    }
    
    func get(scheduleID: String) async -> MessageDisplayHistory {
        recordedCalls[.get, default: 0] += 1
        return currentValue!
    }
}
