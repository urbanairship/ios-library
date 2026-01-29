/* Copyright Airship and Contributors */

import Foundation

/// Resources for AirshipCore
public final class AirshipCoreResources {

    /// Module bundle
    public static let bundle: Bundle = resolveBundle()

    private static func resolveBundle() -> Bundle {
#if SWIFT_PACKAGE
        AirshipLogger.trace("Using Bundle.module for \(moduleName)")
        let bundle = Bundle.module
#if DEBUG
        if bundle.resourceURL == nil {
            assertionFailure("""
            AirshipCore module was built with SWIFT_PACKAGE
            but no resources were found. Check your build configuration.
            """)
        }
#endif
        return bundle
#endif

        return Bundle.airshipFindModule(
            moduleName: "AirshipCore",
            sourceBundle: Bundle(for: Self.self)
        )
    }
}

