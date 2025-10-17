/* Copyright Airship and Contributors */

import Foundation

class AirshipResources {
    static let bundle: Bundle? = findBundle()

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

/**
 * @note For internal use only. :nodoc:
 */
extension String {
    public func airshipLocalizedString(fallback: String) -> String {
        return AirshipResources.localizedString(key: self) ?? fallback
    }
}
