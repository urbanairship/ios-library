/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipPreferenceCenter.
class PreferenceCenterResources {

    public static func localizedString(key: String) -> String? {
        return LocalizationUtils.localizedString(
            key,
            withTable: "UrbanAirship",
            moduleBundle: AirshipCoreResources.bundle
        )
    }
}

extension String {
    var preferenceCenterlocalizedString: String {
        return PreferenceCenterResources.localizedString(key: self) ?? self
    }
}
