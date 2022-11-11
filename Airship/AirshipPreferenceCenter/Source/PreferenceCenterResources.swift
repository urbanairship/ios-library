/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
    import AirshipCore
#endif

/// Resources for AirshipPreferenceCenter.
class PreferenceCenterResources {

    /**
     * Resource bundle for AirshipPreferenceCenter.
     * - Returns: The preference center bundle.
     */
    @objc
    public static func bundle() -> Bundle? {
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: Self.self)

        let path =
            mainBundle.path(
                forResource: "Airship_AirshipPreferenceCenter",
                ofType: "bundle"
            ) ?? mainBundle.path(
                forResource: "AirshipPreferenceCenterResources",
                ofType: "bundle"
            ) ?? sourceBundle.path(
                forResource: "AirshipPreferenceCenterResources",
                ofType: "bundle"
            ) ?? ""

        return Bundle(path: path) ?? sourceBundle
    }

    public static func localizedString(key: String) -> String? {
        return LocalizationUtils.localizedString(
            key,
            withTable: "UrbanAirship",
            moduleBundle: bundle()
        )
    }
}

extension String {
    var localized: String {
        return PreferenceCenterResources.localizedString(key: self) ?? self
    }
}
