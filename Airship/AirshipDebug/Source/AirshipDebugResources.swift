/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipDebug
public final class AirshipDebugResources {
    /// Module bundle
    public static let bundle = resolveBundle()

    private static func resolveBundle() -> Bundle {
#if SWIFT_PACKAGE
        AirshipLogger.trace("Using Bundle.module for AirshipDebug")
        let bundle = Bundle.module
#if DEBUG
        if bundle.resourceURL == nil {
            assertionFailure("""
            AirshipDebug module was built with SWIFT_PACKAGE
            but no resources were found. Check your build configuration.
            """)
        }
#endif
        return bundle
#endif

        return Bundle.airshipFindModule(
            moduleName: "AirshipDebug",
            sourceBundle: Bundle(for: Self.self)
        )
    }

}

extension String {
    func localized(
        bundle: Bundle = AirshipDebugResources.bundle,
        tableName: String = "AirshipDebug",
        comment: String = ""
    ) -> String {
        return NSLocalizedString(
            self,
            tableName: tableName,
            bundle: bundle,
            comment: comment
        )
    }

    func localizedWithFormat(count: Int) -> String {
        return String.localizedStringWithFormat(localized(), count)
    }
}
