/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

/// AirshipAutomation module loader.
/// @note For internal use only. :nodoc:

@objc(UAAutomationSDKModule)
public class AirshipAutomationSDKModule: NSObject, SDKModule {

    public func components() -> [Component] {
        return []
    }

    public static func load(
        withDependencies dependencies: [AnyHashable: Any]
    ) -> SDKModule? {
       return nil
    }
}
