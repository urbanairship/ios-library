/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipFeatureFlags
import AirshipCore

final class FeatureFlagInteractedEventTest: XCTestCase {

    func testMetadata() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reportingMetadata")
            )
        )
        let event = try FeatureFlagInteractedEvent(flag: flag)
        XCTAssertEqual("feature_flag_interaction", event.eventType)
        XCTAssertEqual(EventPriority.normal, event.priority)
    }

    func testData() throws {
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

        let event = try FeatureFlagInteractedEvent(flag: flag)

        let expectedData = [
            "flag_name": "some_flag",
            "reporting_metadata": "reportingMetadata",
            "eligible": true,
            "device": [
                "channel_id": "some_channel",
                "contact_id": "some_contact"
            ]
        ] as [String : Any]

        XCTAssertEqual(try AirshipJSON.wrap(expectedData), try AirshipJSON.wrap(event.data))
    }

    func testDataNoDeviceInfo() throws {
        let flag = FeatureFlag(
            name: "some_flag",
            isEligible: true,
            exists: true,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reportingMetadata")
            )
        )

        let event = try FeatureFlagInteractedEvent(flag: flag)

        let expectedData = [
            "flag_name": "some_flag",
            "reporting_metadata": "reportingMetadata",
            "eligible": true,
        ] as [String : Any]

        XCTAssertEqual(try AirshipJSON.wrap(expectedData), try AirshipJSON.wrap(event.data))
    }



}
