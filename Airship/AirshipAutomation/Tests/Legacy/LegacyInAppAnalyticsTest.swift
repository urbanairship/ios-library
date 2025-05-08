/* Copyright Airship and Contributors */

import Testing
@testable import AirshipAutomation
@testable import AirshipCore

@MainActor
struct LegacyInAppAnalyticsTest {

    private let recoder: EventRecorder = EventRecorder()
    private let analytics: LegacyInAppAnalytics!

    init() {
        self.analytics = LegacyInAppAnalytics(recorder: recoder)
    }

    @Test
    func testDirectOpen() throws {
        self.analytics.recordDirectOpenEvent(scheduleID: "some schedule")
        let eventData = try #require(recoder.eventData.first)
        #expect(eventData.context == nil)
        #expect(eventData.renderedLocale == nil)
        #expect(eventData.messageID == .legacy(identifier: "some schedule"))
        #expect(eventData.source == .airship)

        let expectedJSON = """
        {
           "type":"direct_open"
        }
        """

        #expect(eventData.event.name.reportingName == "in_app_resolution")
        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try eventData.event.bodyJSON
        #expect(actual == expected)
    }

    @Test
    func testReplaced() throws {
        self.analytics.recordReplacedEvent(scheduleID: "some schedule", replacementID: "replacement id")
        let eventData = try #require(recoder.eventData.first)
        #expect(eventData.context == nil)
        #expect(eventData.renderedLocale == nil)
        #expect(eventData.messageID == .legacy(identifier: "some schedule"))
        #expect(eventData.source == .airship)

        let expectedJSON = """
        {
           "type":"replaced",
           "replacement_id": "replacement id"
        }
        """

        #expect(eventData.event.name.reportingName == "in_app_resolution")
        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try eventData.event.bodyJSON
        #expect(actual == expected)    }
}
