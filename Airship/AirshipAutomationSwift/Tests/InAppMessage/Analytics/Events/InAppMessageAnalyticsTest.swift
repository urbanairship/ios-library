/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomationSwift
@testable import AirshipCore

class InAppMessageAnalyticsTest: XCTestCase {

    private let campaigns = try! AirshipJSON.wrap(["campaign1": "data1", "campaign2": "data2"])
    private let experimentResult = ExperimentResult(channelID: "some channel", contactID: "some contact", isMatch: true, reportingMetadata: [AirshipJSON.string("some reporting")])
    private let scheduleID = UUID().uuidString
    private let reportingMetadata = AirshipJSON.string("reporting info")
    private let eventRecorder = EventRecorder()
    private let impressionRecorder = ImpressionRecorder()

    func testSource() async throws {
        let analytics = InAppMessageAnalytics(
            scheduleID: self.scheduleID,
            productID: nil,
            contactID: nil,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .remoteData
            ),
            campaigns: self.campaigns,
            reportingMetadata: self.reportingMetadata,
            experimentResult: self.experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder
        )
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let data = eventRecorder.eventData.first!
        XCTAssertEqual(data.messageID, .airship(identifier: self.scheduleID, campaigns: campaigns))
        XCTAssertEqual(data.source, .airship)
    }

    func testAppDefined() async throws {
        let analytics = InAppMessageAnalytics(
            scheduleID: self.scheduleID,
            productID: nil,
            contactID: nil,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .appDefined
            ),
            campaigns: self.campaigns,
            reportingMetadata: self.reportingMetadata,
            experimentResult: self.experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let data = eventRecorder.eventData.first!
        XCTAssertEqual(data.messageID, .appDefined(identifier: self.scheduleID))
        XCTAssertEqual(data.source, .appDefined)
    }

    func testLegacyMessageID() async throws {
        let analytics = InAppMessageAnalytics(
            scheduleID: self.scheduleID,
            productID: nil,
            contactID: nil,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush
            ),
            campaigns: self.campaigns,
            reportingMetadata: self.reportingMetadata,
            experimentResult: self.experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let data = eventRecorder.eventData.first!
        XCTAssertEqual(data.messageID, .legacy(identifier: self.scheduleID))
        XCTAssertEqual(data.source, .airship)
    }

    func testData() async throws {
        let thomasLayoutContext  = ThomasLayoutContext(
            formInfo: ThomasFormInfo(
                identifier: UUID().uuidString,
                submitted: true,
                formType: UUID().uuidString,
                formResponseType: UUID().uuidString
            ),
            pagerInfo: ThomasPagerInfo(
                identifier: UUID().uuidString,
                pageIndex: 1,
                pageIdentifier: UUID().uuidString,
                pageCount: 2,
                completed: false
            ),
            buttonInfo: ThomasButtonInfo(identifier: UUID().uuidString)
        )

        let expectedContext = InAppEventContext.makeContext(
            reportingContext: self.reportingMetadata,
            experimentsResult: self.experimentResult,
            layoutContext: thomasLayoutContext
        )
        
        let analytics = InAppMessageAnalytics(
            scheduleID: self.scheduleID,
            productID: nil,
            contactID: nil,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            campaigns: self.campaigns,
            reportingMetadata: self.reportingMetadata,
            experimentResult: self.experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: thomasLayoutContext)

        let data = self.eventRecorder.eventData.first!
        XCTAssertEqual(data.context, expectedContext)
        XCTAssertEqual(data.renderedLocale, AirshipJSON.string("rendered locale"))
        XCTAssertEqual(data.event.name, "test_event")
    }
    
    func testImpression() async throws {
        let productId = "test-product-id"
        let contactId = "test-contact-id"
        
        let date = UATestDate(offset: 0, dateOverride: Date())
        
        let analytics = InAppMessageAnalytics(
            scheduleID: self.scheduleID,
            productID: productId,
            contactID: contactId,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            campaigns: self.campaigns,
            reportingMetadata: self.reportingMetadata,
            experimentResult: self.experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder,
            date: date
        )
        
        await analytics.recordImpression()
        
        let impression = try XCTUnwrap(impressionRecorder.lastRecordedImpression)
        XCTAssertEqual(self.scheduleID, impression.entityID)
        XCTAssertEqual(AirshipMeteredUsageType.inAppExperienceImpression, impression.usageType)
        XCTAssertEqual(productId, impression.product)
        XCTAssertEqual(self.reportingMetadata, impression.reportingContext)
        XCTAssertEqual(date.now, impression.timestamp)
        XCTAssertEqual(contactId, impression.contactId)
    }

    func testReportingDisabled() async throws {
        let analytics = InAppMessageAnalytics(
            scheduleID: self.scheduleID,
            productID: nil,
            contactID: nil,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                isReportingEnabled: false,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            campaigns: self.campaigns,
            reportingMetadata: self.reportingMetadata,
            experimentResult: self.experimentResult,
            eventRecorder: eventRecorder,
            impressionRecorder: impressionRecorder
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        XCTAssertTrue(self.eventRecorder.eventData.isEmpty)
        XCTAssertNil(impressionRecorder.lastRecordedImpression)
    }
}

final class EventRecorder: InAppEventRecorderProtocol, @unchecked Sendable {
    var eventData: [InAppEventData] = []
    func recordEvent(inAppEventData: InAppEventData) {
        eventData.append(inAppEventData)
    }
}

final class ImpressionRecorder: AirshipMeteredUsageProtocol, @unchecked Sendable {
    var lastRecordedImpression: AirshipMeteredUsageEvent?
    
    func addEvent(_ event: AirshipCore.AirshipMeteredUsageEvent) async throws {
        lastRecordedImpression = event
    }
    
    
}
