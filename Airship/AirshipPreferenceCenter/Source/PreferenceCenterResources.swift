/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipPreferenceCenter.
class PreferenceCenterResources {

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
        return PreferenceCenterResources.localizedString(key: self) ?? self
    }
}
