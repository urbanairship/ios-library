/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

/// AirshipAutomation module loader.
/// @note For internal use only. :nodoc:

@objc(UAAutomationSDKModule)
public class AirshipAutomationSDKModule: NSObject, AirshipSDKModule {


    public var actionsManifest: ActionsManifest? = nil

    public var components: [AirshipComponent] = []


    public static func load(dependencies: [String : Any]) -> AirshipSDKModule? {
        return nil
    }
}
