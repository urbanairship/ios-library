/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
public import AirshipCore
#endif

import Foundation

/// AirshipFeatureFlags module loader.
/// @note For internal use only. :nodoc:

@objc(UAFeatureFlagsSDKModule)
public class AirshipFeatureFlagsSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: (any ActionsManifest)? = nil

    public let components: [any AirshipComponent]

    public static func load(dependencies: [String : Any]) -> (any AirshipSDKModule)? {
        let dataStore =
            dependencies[SDKDependencyKeys.dataStore] as! PreferenceDataStore
        let remoteData =
        dependencies[SDKDependencyKeys.remoteData] as! (any RemoteDataProtocol)

        let airshipAnalytcs = dependencies[SDKDependencyKeys.analytics] as! (any InternalAnalyticsProtocol)
        let deferredResolver = dependencies[SDKDependencyKeys.deferredResolver] as! (any AirshipDeferredResolverProtocol)
        let cache = dependencies[SDKDependencyKeys.cache] as! (any AirshipCache)
        let privacyManager =
            dependencies[SDKDependencyKeys.privacyManager] as! AirshipPrivacyManager
        
        let manager = FeatureFlagManager(
            dataStore: dataStore,
            remoteDataAccess: FeatureFlagRemoteDataAccess(remoteData: remoteData),
            analytics: FeatureFlagAnalytics(airshipAnalytics: airshipAnalytcs),
            deferredResolver: FeatureFlagDeferredResolver(
                cache: cache,
                deferredResolver: deferredResolver
            ), 
            privacyManager: privacyManager
        )

        let component = FeatureFlagComponent(featureFlagManager: manager)
        return AirshipFeatureFlagsSDKModule(components: [component])
    }

    init(components: [any AirshipComponent]) {
        self.components = components
    }
}
