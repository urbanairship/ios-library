/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipFeatureFlags
@testable import AirshipCore

final class FeatureFlagAnalyticsTest: XCTestCase {
    private let airshipAnalytics: TestAnalytics = TestAnalytics()
    private var analytics: FeatureFlagAnalytics!

    override func setUp() {
        self.analytics = FeatureFlagAnalytics(airshipAnalytics: airshipAnalytics)
    }

    func testTrackInteractionDoesNotExist() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: false,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting two"),
                contactID: "some contactID",
                channelID: "some channel ID"
            )
        )

        self.analytics.trackInteraction(flag: flag)
        XCTAssertEqual(0, self.airshipAnalytics.events.count)
    }

    func testTrackInteractionNoReportingInfo() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: nil
        )

        self.analytics.trackInteraction(flag: flag)
        XCTAssertEqual(0, self.airshipAnalytics.events.count)
    }

    func testTrackInteraction() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reportingMetadata"),
                contactID: "some_contact",
                channelID: "some_channel"
            )
        )

        let expectedBody = """
        {
            "flag_name": "some_flag",
            "reporting_metadata": "reportingMetadata",
            "eligible": true,
            "device": {
                "channel_id": "some_channel",
                "contact_id": "some_contact"
            }
        }
        """

        self.analytics.trackInteraction(flag: flag)
        XCTAssertEqual(1, self.airshipAnalytics.events.count)

        let event = self.airshipAnalytics.events.first!
        XCTAssertEqual("feature_flag_interaction", event.eventType.reportingName)
        XCTAssertEqual(AirshipEventPriority.normal, event.priority)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    func testTrackInteractionNoDeviceInfo() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reportingMetadata")
            )
        )

        let expectedBody = """
        {
            "flag_name": "some_flag",
            "reporting_metadata": "reportingMetadata",
            "eligible": true
        }
        """

        self.analytics.trackInteraction(flag: flag)
        XCTAssertEqual(1, self.airshipAnalytics.events.count)

        let event = self.airshipAnalytics.events.first!
        XCTAssertEqual("feature_flag_interaction", event.eventType.reportingName)
        XCTAssertEqual(AirshipEventPriority.normal, event.priority)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    func testTrackInteractionEventFeed() async throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reportingMetadata")
            )
        )

        var feed = await self.airshipAnalytics.eventFeed.updates.makeAsyncIterator()
        
        self.analytics.trackInteraction(flag: flag)

        let event = self.airshipAnalytics.events.first!
        XCTAssertEqual(1, self.airshipAnalytics.events.count)
        
        let next = await feed.next()
        XCTAssertEqual(next, .analytics(eventType: .featureFlagInteraction, body: event.eventData))
    }
}
