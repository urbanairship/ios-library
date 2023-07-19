/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

/// AirshipFeatureFlags module loader.
/// @note For internal use only. :nodoc:

@objc(UAFeatureFlagsSDKModule)
public class AirshipFeatureFlagsSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: ActionsManifest? = nil

    public let components: [AirshipComponent]

    public static func load(dependencies: [String : Any]) -> AirshipSDKModule? {
        let dataStore =
            dependencies[SDKDependencyKeys.dataStore] as! PreferenceDataStore
        let remoteData =
            dependencies[SDKDependencyKeys.remoteData] as! RemoteDataProtocol


        let manager = FeatureFlagManager(
            dataStore: dataStore,
            remoteDataAccess: FeatureFlagRemoteDataAccess(remoteData: remoteData)
        )
        return AirshipFeatureFlagsSDKModule(components: [manager])
    }

    init(components: [AirshipComponent]) {
        self.components = components
    }
}
