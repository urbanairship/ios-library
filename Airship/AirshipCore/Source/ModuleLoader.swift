/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
public struct AirshiopModuleLoaderArgs {
    public let config: RuntimeConfig
    public let dataStore: PreferenceDataStore
    public let channel: any InternalAirshipChannelProtocol&AirshipChannelProtocol
    public let contact: any AirshipContactProtocol
    public let push: any AirshipPushProtocol
    public let remoteData: any RemoteDataProtocol
    public let analytics: any InternalAnalyticsProtocol&AirshipAnalyticsProtocol
    public let privacyManager: any PrivacyManagerProtocol
    public let permissionsManager: AirshipPermissionsManager
    public let experimentsManager: any ExperimentDataProvider
    public let meteredUsage: AirshipMeteredUsage
    public let deferredResolver: any AirshipDeferredResolverProtocol
    public let cache: any AirshipCache
    public let audienceChecker: any DeviceAudienceChecker
    public let workManager: any AirshipWorkManagerProtocol
    public let inputValidator: any AirshipInputValidation.Validator

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
        privacyManager: any PrivacyManagerProtocol,
        permissionsManager: AirshipPermissionsManager,
        audienceOverrides: any AudienceOverridesProvider,
        experimentsManager: any ExperimentDataProvider,
        meteredUsage: AirshipMeteredUsage,
        deferredResolver: any AirshipDeferredResolverProtocol,
        cache: any AirshipCache,
        audienceChecker: any DeviceAudienceChecker,
        inputValidator: any AirshipInputValidation.Validator
    ) {

        let args = AirshiopModuleLoaderArgs(
            config: config,
            dataStore: dataStore,
            channel: channel,
            contact: contact,
            push: push,
            remoteData: remoteData,
            analytics: analytics,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            experimentsManager: experimentsManager,
            meteredUsage: meteredUsage,
            deferredResolver: deferredResolver,
            cache: cache,
            audienceChecker: audienceChecker,
            workManager: AirshipWorkManager.shared,
            inputValidator: inputValidator
        )

        let modules = ModuleLoader.loadModules(args)
        self.components = modules.compactMap { $0.components }.reduce([], +)
        self.actionManifests = modules.compactMap { $0.actionsManifest }
    }

    @MainActor
    private class func loadModules(_ args: AirshiopModuleLoaderArgs) -> [any AirshipSDKModule]
    {
        let sdkModules: [any AirshipSDKModule] = SDKModuleNames.allCases.compactMap {
            guard
                let moduleClass = NSClassFromString($0.rawValue) as? any AirshipSDKModule.Type
            else {
                return nil
            }

            AirshipLogger.debug("Loading module \($0)")
            return moduleClass.load(args)
        }

        return sdkModules
    }
}
