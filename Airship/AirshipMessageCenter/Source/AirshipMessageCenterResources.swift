/* Copyright Airship and Contributors */


@_spi(AirshipInternal) import AirshipBasement
import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Resources for AirshipMessageCenter
final class AirshipMessageCenterResources {
    
    /// Module bundle
    static let bundle: Bundle = resolveBundle()

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

    static func localizedString(key: String) -> String? {
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
