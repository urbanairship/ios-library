/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
@testable import AirshipCore

final class LegacyInAppAnalyticsTest: XCTestCase {

    private let recoder: EventRecorder = EventRecorder()
    private var analytics: LegacyInAppAnalytics!

    override func setUp() async throws {
        self.analytics = LegacyInAppAnalytics(recorder: recoder)
    }

    func testDirectOpen() {
        self.analytics.recordDirectOpenEvent(scheduleID: "some schedule")
        let eventData = recoder.eventData.first!
        XCTAssertNil(eventData.context)
        XCTAssertNil(eventData.renderedLocale)
        XCTAssertEqual(eventData.messageID, .legacy(identifier: "some schedule"))
        XCTAssertEqual(eventData.source, .airship)

        let expectedJSON = """
        {
           "type":"direct_open"
        }
        """

        XCTAssertEqual(eventData.event.name, "in_app_resolution")
        XCTAssertEqual(try eventData.event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))

    }

    func testReplaced() {
        self.analytics.recordReplacedEvent(scheduleID: "some schedule", replacementID: "replacement id")
        let eventData = recoder.eventData.first!
        XCTAssertNil(eventData.context)
        XCTAssertNil(eventData.renderedLocale)
        XCTAssertEqual(eventData.messageID, .legacy(identifier: "some schedule"))
        XCTAssertEqual(eventData.source, .airship)

        let expectedJSON = """
        {
           "type":"replaced",
           "replacement_id": "replacement id"
        }
        """

        XCTAssertEqual(eventData.event.name, "in_app_resolution")
        XCTAssertEqual(try eventData.event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }
}
