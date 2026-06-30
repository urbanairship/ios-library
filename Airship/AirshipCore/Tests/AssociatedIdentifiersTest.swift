/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore

@Suite struct AssociatedIdentifiersTest {

    @Test
    func testIDs() {
        let identifiers = AssociatedIdentifiers(identifiers: ["custom key": "custom value"])
        identifiers.vendorID = "vendor ID"
        identifiers.advertisingID = "advertising ID"
        identifiers.advertisingTrackingEnabled = false
        identifiers.set(identifier: "another custom value", key: "another custom key")

        #expect("vendor ID" == identifiers.allIDs["com.urbanairship.vendor"])
        #expect("advertising ID" == identifiers.allIDs["com.urbanairship.idfa"])
        #expect(!(identifiers.advertisingTrackingEnabled))
        #expect("true" == identifiers.allIDs["com.urbanairship.limited_ad_tracking_enabled"])
        #expect("another custom value" == identifiers.allIDs["another custom key"])

        identifiers.advertisingTrackingEnabled = true
        #expect(identifiers.advertisingTrackingEnabled)
        #expect("false" == identifiers.allIDs["com.urbanairship.limited_ad_tracking_enabled"])
    }
}
