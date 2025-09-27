/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

class AirshipLocalizationUtilsTest: XCTestCase {

    func testLocalization() {
        let localizedString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle
        )
        XCTAssertEqual(localizedString, "Yes")

        let badKeyString = AirshipLocalizationUtils.localizedString(
            "not_a_key",
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle
        )
        XCTAssertNil(badKeyString)

        let badTableString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "NotATable",
            moduleBundle: AirshipCoreResources.bundle
        )
        XCTAssertNil(badTableString)
    }
}
