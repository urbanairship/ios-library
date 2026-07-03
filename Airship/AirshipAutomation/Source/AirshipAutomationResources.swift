/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

import AirshipCore

/// Resources for AirshipAutomation
public final class AirshipAutomationResources {
    /// Module bundle
    public static let bundle: Bundle = resolveBundle()

    private static func resolveBundle() -> Bundle {
#if SWIFT_PACKAGE
        AirshipLogger.trace("Using Bundle.module for AirshipAutomation")
        let bundle = Bundle.module
#if DEBUG
        if bundle.resourceURL == nil {
            assertionFailure("""
            AirshipAutomation module was built with SWIFT_PACKAGE
            but no resources were found. Check your build configuration.
            """)
        }
#endif
        return bundle
#endif

        return Bundle.airshipFindModule(
            moduleName: "AirshipAutomation",
            sourceBundle: Bundle(for: Self.self)
        )
    }
}
