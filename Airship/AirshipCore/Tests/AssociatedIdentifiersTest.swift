/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AssociatedIdentifiersTest: XCTestCase {

    func testIDs() {
        let identifiers = AssociatedIdentifiers(dictionary: ["custom key": "custom value"])
        identifiers.vendorID = "vendor ID"
        identifiers.advertisingID = "advertising ID"
        identifiers.advertisingTrackingEnabled = false
        identifiers.set(identifier: "another custom value", key: "another custom key")

        XCTAssertEqual("vendor ID", identifiers.allIDs["com.urbanairship.vendor"])
        XCTAssertEqual("advertising ID", identifiers.allIDs["com.urbanairship.idfa"])
        XCTAssertFalse(identifiers.advertisingTrackingEnabled)
        XCTAssertEqual("true", identifiers.allIDs["com.urbanairship.limited_ad_tracking_enabled"])
        XCTAssertEqual("another custom value", identifiers.allIDs["another custom key"])

        identifiers.advertisingTrackingEnabled = true
        XCTAssertTrue(identifiers.advertisingTrackingEnabled)
        XCTAssertEqual("false", identifiers.allIDs["com.urbanairship.limited_ad_tracking_enabled"])
    }
}
