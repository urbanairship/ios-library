/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable
import AirshipFeatureFlags
@_spi(AirshipInternal) @testable import AirshipCore

struct FeatureFlagAnalyticsTest {
    private let airshipAnalytics: TestAnalytics = TestAnalytics()
    private let analytics: FeatureFlagAnalytics

    init() {
        self.analytics = FeatureFlagAnalytics(airshipAnalytics: airshipAnalytics)
    }

    @Test
    func testTrackInteractionDoesNotExist() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: false,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting two",
                contactID: "some contactID",
                channelID: "some channel ID"
            )
        )

        self.analytics.trackInteraction(flag: flag)
        #expect(self.airshipAnalytics.events.count == 0)
    }

    @Test
    func testTrackInteractionNoReportingInfo() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: nil
        )

        self.analytics.trackInteraction(flag: flag)
        #expect(self.airshipAnalytics.events.count == 0)
    }

    @Test
    func testTrackInteraction() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reportingMetadata",
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
        #expect(self.airshipAnalytics.events.count == 1)

        let event = self.airshipAnalytics.events.first!
        #expect(event.eventType.reportingName == "feature_flag_interaction")
        #expect(event.priority == AirshipEventPriority.normal)
        #expect(try AirshipJSON.from(json: expectedBody) == event.eventData)
    }
    
    @Test
    func testTrackInteractionSupersede() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reportingMetadata",
                supersededReportingMetadata: ["supersede"],
                contactID: "some_contact",
                channelID: "some_channel"
            )
        )

        let expectedBody = """
        {
            "flag_name": "some_flag",
            "reporting_metadata": "reportingMetadata",
            "superseded_reporting_metadata": ["supersede"],
            "eligible": true,
            "device": {
                "channel_id": "some_channel",
                "contact_id": "some_contact"
            }
        }
        """

        self.analytics.trackInteraction(flag: flag)
        #expect(self.airshipAnalytics.events.count == 1)

        let event = self.airshipAnalytics.events.first!
        #expect(event.eventType.reportingName == "feature_flag_interaction")
        #expect(event.priority == AirshipEventPriority.normal)
        #expect(try AirshipJSON.from(json: expectedBody) == event.eventData)
    }

    @Test
    func testTrackInteractionNoDeviceInfo() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reportingMetadata"
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
        #expect(self.airshipAnalytics.events.count == 1)

        let event = self.airshipAnalytics.events.first!
        #expect(event.eventType.reportingName == "feature_flag_interaction")
        #expect(event.priority == AirshipEventPriority.normal)
        #expect(try AirshipJSON.from(json: expectedBody) == event.eventData)
    }

    @Test
    func testTrackInteractionEventFeed() async throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reportingMetadata"
            )
        )

        var feed = await self.airshipAnalytics.eventFeed.updates.makeAsyncIterator()
        
        self.analytics.trackInteraction(flag: flag)

        let event = self.airshipAnalytics.events.first!
        #expect(self.airshipAnalytics.events.count == 1)
        
        let next = await feed.next()
        #expect(next == .analytics(eventType: .featureFlagInteraction, body: event.eventData))
    }
}
