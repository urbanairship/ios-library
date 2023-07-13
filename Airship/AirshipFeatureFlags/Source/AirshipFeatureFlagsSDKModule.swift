/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

/// AirshipFeatureFlags module loader.
/// @note For internal use only. :nodoc:

@objc(UAFeatureFlagsSDKModule)
public class AirshipFeatureFlagsSDKModule: NSObject, AirshipSDKModule {
    public var actionsManifest: ActionsManifest? = nil

    public var components: [AirshipComponent] = []

    public static func load(dependencies: [String : Any]) -> AirshipSDKModule? {
        return nil
    }
    
    /*
     
    init(featureFlags: FeatureFlags) {
        self.components = [featureFlags]
    }
     */
}
