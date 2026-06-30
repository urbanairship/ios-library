/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@Suite struct AirshipLocalizationUtilsTest {

    @Test
    func testLocalization() {
        let localizedString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle
        )
        #expect(localizedString == "Yes")

        let badKeyString = AirshipLocalizationUtils.localizedString(
            "not_a_key",
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle
        )
        #expect(badKeyString == nil)

        let badTableString = AirshipLocalizationUtils.localizedString(
            "ua_notification_button_yes",
            withTable: "NotATable",
            moduleBundle: AirshipCoreResources.bundle
        )
        #expect(badTableString == nil)
    }
}
