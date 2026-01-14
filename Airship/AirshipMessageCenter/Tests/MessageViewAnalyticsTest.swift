/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
@testable import AirshipMessageCenter

struct DefaultMessageViewAnalyticsTests {

    let mockRecorder = MockThomasLayoutEventRecorder()

    @Test("Record event captures correct data with default Airship source")
    @MainActor
    func recordEventDefaults() async throws {
        
        let messageID = "test-message-id"
        let reportingContext = ["test": AirshipJSON.string("reporting")]
        let message = createStubMessage(id: messageID, reporting: reportingContext)
        
        let analytics = DefaultMessageViewAnalytics(
            message: message,
            eventRecorder: mockRecorder
        )
        
        let layoutContext = ThomasLayoutContext()

        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: layoutContext)

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
    
    // MARK: - Helpers
    private func createStubMessage(id: String, reporting: [String: Any]?) -> MessageCenterMessage {
        // Replace with your actual MessageCenterMessage initialization
        return MessageCenterMessage(
            title: "Test Title",
            id: id,
            contentType: .html,
            extra: [:],
            bodyURL: .init(string: "https://test.url")!,
            expirationDate: nil,
            messageReporting: reporting,
            unread: true,
            sentDate: Date(),
            messageURL: .init(string: "https://test.url")!,
            rawMessageObject: [:]
        )
    }
}

class MockThomasLayoutEventRecorder: ThomasLayoutEventRecorderProtocol, @unchecked Sendable {
    private(set) var lastRecordedImpression: AirshipMeteredUsageEvent? = nil
    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent) {
        lastRecordedImpression = event
    }
    
    private(set) var lastCapturedData: ThomasLayoutEventData? = nil
    func recordEvent(inAppEventData: ThomasLayoutEventData) {
        lastCapturedData = inAppEventData
    }
}
