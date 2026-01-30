/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipPreferenceCenter.
public final class AirshipPreferenceCenterResources {

    public static func localizedString(key: String) -> String? {
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
