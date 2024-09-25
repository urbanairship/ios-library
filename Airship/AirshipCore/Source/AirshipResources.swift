/* Copyright Airship and Contributors */

import Foundation

class AirshipResources {
    static var bundle: Bundle? = findBundle()

    /// Assumes AirshipResources class and UrbanAirship.string resource always exist in the same bundle
    private static func findBundle() -> Bundle? {
        return Bundle(for: AirshipResources.self)
    }

    public static func localizedString(key: String) -> String? {
        return AirshipLocalizationUtils.localizedString(
            key,
            withTable: "UrbanAirship",
            moduleBundle: bundle
        )
    }
}

extension String {
    var airshipLocalizedString: String {
        return AirshipResources.localizedString(key: self) ?? self
    }
}
