/* Copyright Airship and Contributors */

import Foundation

/// Resources for AirshipCore
public final class AirshipCoreResources {

    /// Module bundle
    public static let bundle = Bundle.airshipModule(
        moduleName: "AirshipCore",
        sourceBundle: Bundle(for: AirshipCoreResources.self)
    )
}

