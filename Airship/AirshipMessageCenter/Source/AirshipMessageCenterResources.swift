/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipMessageCenter
public final class AirshipMessageCenterResources {
    /// Module bundle
    public static let bundle = Bundle.airshipModule(
        moduleName: "AirshipMessageCenter",
        sourceBundle: Bundle(for: AirshipMessageCenterResources.self)
    )

    public static func localizedString(key: String) -> String? {
        return AirshipLocalizationUtils.localizedString(
            key,
            withTable: "UrbanAirship",
            moduleBundle: bundle
        )
    }
}

extension String {
    var messageCenterLocalizedString: String {
        return AirshipMessageCenterResources.localizedString(key: self) ?? self
    }
}
