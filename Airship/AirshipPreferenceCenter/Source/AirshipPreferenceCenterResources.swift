/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

/// Resources for AirshipPreferenceCenter.
final class AirshipPreferenceCenterResources {

    static func localizedString(key: String) -> String? {
        return AirshipLocalizationUtils.localizedString(
            key,
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle
        )
    }
}

extension String {
    var preferenceCenterLocalizedString: String {
        return AirshipPreferenceCenterResources.localizedString(key: self) ?? self
    }
}
