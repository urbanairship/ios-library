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

    public static func load(_ args: AirshiopModuleLoaderArgs) -> (any AirshipSDKModule)? {
        let manager = DefaultFeatureFlagManager(
            dataStore: args.dataStore,
            remoteDataAccess: FeatureFlagRemoteDataAccess(remoteData: args.remoteData),
            remoteData: args.remoteData,
            analytics: FeatureFlagAnalytics(airshipAnalytics: args.analytics),
            audienceChecker: args.audienceChecker,
            deferredResolver: FeatureFlagDeferredResolver(
                cache: args.cache,
                deferredResolver: args.deferredResolver
            ),
            privacyManager: args.privacyManager,
            resultCache: DefaultFeatureFlagResultCache(cache: args.cache)
        )

        let component = FeatureFlagComponent(featureFlagManager: manager)
        return AirshipFeatureFlagsSDKModule(components: [component])
    }

    init(components: [any AirshipComponent]) {
        self.components = components
    }
}
