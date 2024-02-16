/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

class AirshipLocalizationUtilsTest: XCTestCase {

    func testDefaultValue() {
        let localizedString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle,
            defaultValue: "howdy"
        )
        XCTAssertEqual(localizedString, "Yes")

        let badKeyString = AirshipLocalizationUtils.localizedString(
            "not_a_key",
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle,
            defaultValue: "howdy"
        )
        XCTAssertEqual(badKeyString, "howdy")

        let badTableString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "NotATable",
            moduleBundle: AirshipCoreResources.bundle,
            defaultValue: "howdy"
        )
        XCTAssertEqual(badTableString, "howdy")
    }

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
        XCTAssertEqual(badKeyString, "not_a_key")

        let badTableString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "NotATable",
            moduleBundle: AirshipCoreResources.bundle
        )
        XCTAssertEqual(badTableString, "ua_notification_button_yes")
    }
}
