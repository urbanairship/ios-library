/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipDebug
public final class AirshipDebugResources {
    /// Module bundle
    public static let bundle = Bundle.airshipModule(
        moduleName: "AirshipDebug",
        sourceBundle: Bundle(for: AirshipDebugResources.self)
    )
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
