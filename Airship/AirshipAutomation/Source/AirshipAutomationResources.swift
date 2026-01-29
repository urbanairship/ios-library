/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Resources for AirshipAutomation
public final class AirshipAutomationResources {
    /// Module bundle
    public static let bundle = Bundle.airshipModule(
        moduleName: "AirshipAutomation",
        sourceBundle: Bundle(for: AirshipAutomationResources.self)
    )
}
