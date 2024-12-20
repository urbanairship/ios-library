/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct SDKDependencyKeys {
    public static let channel = "channel"
    public static let contact = "contact"
    public static let push = "push"
    public static let remoteData = "remote_data"
    public static let config = "config"
    public static let dataStore = "dataStore"
    public static let analytics = "analytics"
    public static let privacyManager = "privacy_manager"
    public static let permissionsManager = "permissions_manager"
    public static let workManager = "work_manager"
    public static let deferredResolver = "deferred_resolver"
    public static let cache = "airship_cache"
    public static let experimentsProvider = "experiments"
    public static let meteredUsage = "metered_usage"
    public static let sceneManager = "scene_manager"
    public static let audienceChecker = "audience_checker"

}

/// NOTE: For internal use only. :nodoc:
enum SDKModuleNames: String, CaseIterable {
    case messageCenter = "UAMessageCenterSDKModule"
    case preferenceCenter = "UAPreferenceCenterSDKModule"
    case debug = "UADebugSDKModule"
    case featureFlags = "UAFeatureFlagsSDKModule"
    case automation = "UAAutomationSDKModule"
}

/// NOTE: For internal use only. :nodoc:
class ModuleLoader {

    public let components: [any AirshipComponent]

    public let actionManifests: [any ActionsManifest]

    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: AirshipChannel,
        contact: AirshipContact,
        push: AirshipPush,
        remoteData: any RemoteDataProtocol,
        analytics: AirshipAnalytics,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        audienceOverrides: any AudienceOverridesProvider,
        experimentsManager: any ExperimentDataProvider,
        meteredUsage: AirshipMeteredUsage,
        deferredResolver: any AirshipDeferredResolverProtocol,
        cache: any AirshipCache,
        audienceChecker: any DeviceAudienceChecker
    ) {

        var dependencies: [String: Any] = [
            SDKDependencyKeys.config: config,
            SDKDependencyKeys.dataStore: dataStore,
            SDKDependencyKeys.channel: channel,
            SDKDependencyKeys.contact: contact,
            SDKDependencyKeys.push: push,
            SDKDependencyKeys.remoteData: remoteData,
            SDKDependencyKeys.analytics: analytics,
            SDKDependencyKeys.privacyManager: privacyManager,
            SDKDependencyKeys.permissionsManager: permissionsManager,
            SDKDependencyKeys.workManager: AirshipWorkManager.shared,
            SDKDependencyKeys.deferredResolver: deferredResolver,
            SDKDependencyKeys.cache: cache,
            SDKDependencyKeys.experimentsProvider: experimentsManager,
            SDKDependencyKeys.meteredUsage: meteredUsage,
            SDKDependencyKeys.audienceChecker: audienceChecker
        ]

#if !os(watchOS)
        dependencies[SDKDependencyKeys.sceneManager] = AirshipSceneManager.shared
#endif

        let swiftModules = ModuleLoader.loadModules(dependencies)
        let swiftComponents = swiftModules.compactMap { $0.components }.reduce([], +)
        let swiftActionManifests = swiftModules.compactMap { $0.actionsManifest }


        self.components = swiftComponents
        self.actionManifests = swiftActionManifests
    }

    @MainActor
    private class func loadModules(_ dependencies: [String: Any]) -> [any AirshipSDKModule]
    {
        let sdkModules: [any AirshipSDKModule] = SDKModuleNames.allCases.compactMap {
            guard
                let moduleClass = NSClassFromString($0.rawValue) as? any AirshipSDKModule.Type
            else {
                return nil
            }

            AirshipLogger.debug("Loading module \($0)")
            return moduleClass.load(dependencies: dependencies)
        }

        return sdkModules
    }
}
