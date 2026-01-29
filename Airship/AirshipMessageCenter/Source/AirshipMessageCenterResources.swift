/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipMessageCenter
public final class AirshipMessageCenterResources {
    
    /// Module bundle
    public static let bundle = resolveBundle()

    private static func resolveBundle() -> Bundle {
#if SWIFT_PACKAGE
        AirshipLogger.trace("Using Bundle.module for AirshipMessageCenter")
        let bundle = Bundle.module
#if DEBUG
        if bundle.resourceURL == nil {
            assertionFailure("""
            AirshipMessageCenter module was built with SWIFT_PACKAGE
            but no resources were found. Check your build configuration.
            """)
        }
#endif
        return bundle
#endif

        return Bundle.airshipFindModule(
            moduleName: "AirshipMessageCenter",
            sourceBundle: Bundle(for: Self.self)
        )
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
    var messageCenterLocalizedString: String {
        return AirshipMessageCenterResources.localizedString(key: self) ?? self
    }
}
