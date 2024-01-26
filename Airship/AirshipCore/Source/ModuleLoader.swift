/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
@objc(UASDKDependencyKeys)
public class SDKDependencyKeys: NSObject {
    @objc
    public static let channel = "channel"
    @objc
    public static let contact = "contact"
    @objc
    public static let push = "push"
    @objc
    public static let remoteData = "remote_data"
    @objc
    public static let inAppCoreSwiftBridge = "iaa_core_swift_bridge"
    @objc
    public static let config = "config"
    @objc
    public static let dataStore = "dataStore"
    @objc
    public static let analytics = "analytics"
    @objc
    public static let privacyManager = "privacy_manager"
    @objc
    public static let permissionsManager = "permissions_manager"
    @objc
    public static let workManager = "work_manager"

    public static let deferredResolver = "deferred_resolver"

    public static let cache = "airship_cache"

    public static let experimentsProvider = "experiments"
    public static let meteredUsage = "metered_usage"
    public static let sceneManager = "scene_manager"
    public static let applicationMetrics = "application_metrics"


}

/// NOTE: For internal use only. :nodoc:
enum SDKModuleNames: String, CaseIterable {
    case messageCenter = "UAMessageCenterSDKModule"
    case preferenceCenter = "UAPreferenceCenterSDKModule"
    case debug = "UADebugSDKModule"
    case featureFlags = "UAFeatureFlagsSDKModule"
}

/// NOTE: For internal use only. :nodoc:
enum LegacySDKModuleNames: String, CaseIterable {
    case automation = "UAAutomationSDKModule"
}

/// NOTE: For internal use only. :nodoc:
class ModuleLoader {

    public let components: [AirshipComponent]

    public let actionManifests: [ActionsManifest]

    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: AirshipChannel,
        contact: AirshipContact,
        push: AirshipPush,
        remoteData: RemoteDataProtocol,
        analytics: AirshipAnalytics,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        audienceOverrides: AudienceOverridesProvider,
        experimentsManager: ExperimentDataProvider,
        meteredUsage: AirshipMeteredUsage,
        deferredResolver: AirshipDeferredResolverProtocol,
        cache: AirshipCache,
        metrics: ApplicationMetrics
    ) {

        var dependencies: [String: Any] = [
            SDKDependencyKeys.config: config,
            SDKDependencyKeys.dataStore: dataStore,
            SDKDependencyKeys.channel: channel,
            SDKDependencyKeys.contact: contact,
            SDKDependencyKeys.push: push,
            SDKDependencyKeys.remoteData: remoteData,
            SDKDependencyKeys.inAppCoreSwiftBridge: _InAppCoreSwiftBridge(
                remoteData: remoteData,
                meteredUsage: meteredUsage,
                contact: contact,
                deferredResolver: deferredResolver,
                experimentProvider: experimentsManager
            ),
            SDKDependencyKeys.analytics: analytics,
            SDKDependencyKeys.privacyManager: privacyManager,
            SDKDependencyKeys.permissionsManager: permissionsManager,
            SDKDependencyKeys.workManager: AirshipWorkManager.shared,
            SDKDependencyKeys.deferredResolver: deferredResolver,
            SDKDependencyKeys.cache: cache,
            SDKDependencyKeys.experimentsProvider: experimentsManager,
            SDKDependencyKeys.meteredUsage: meteredUsage,
            SDKDependencyKeys.applicationMetrics: metrics
        ]

#if !os(watchOS)
        dependencies[SDKDependencyKeys.sceneManager] = SceneManager.shared
#endif

        let swiftModules = ModuleLoader.loadModules(dependencies)
        let swiftComponents = swiftModules.compactMap { $0.components }.reduce([], +)
        let swiftActionManifests = swiftModules.compactMap { $0.actionsManifest }

        let objcModules = ModuleLoader.loadLegacyModules(dependencies)
        let objcComponents = objcModules.compactMap { $0.components?() }.reduce([], +)
        let objcActionManifests: [ActionsManifest] = objcModules.compactMap {
            $0.actions?()
        }.map {
            LegacyActionsManifest(actions: $0)
        }

        self.components = swiftComponents + objcComponents
        self.actionManifests = swiftActionManifests + objcActionManifests
    }

    @MainActor
    private class func loadModules(_ dependencies: [String: Any]) -> [AirshipSDKModule]
    {
        let sdkModules: [AirshipSDKModule] = SDKModuleNames.allCases.compactMap {
            guard
                let moduleClass = NSClassFromString($0.rawValue) as? AirshipSDKModule.Type
            else {
                return nil
            }

            AirshipLogger.debug("Loading module \($0)")
            return moduleClass.load(dependencies: dependencies)
        }

        return sdkModules
    }


    @MainActor
    private class func loadLegacyModules(_ dependencies: [String: Any]) -> [UALegacySDKModule]
    {
        let sdkModules: [UALegacySDKModule] = LegacySDKModuleNames.allCases.compactMap {
            guard
                let moduleClass = NSClassFromString($0.rawValue) as? UALegacySDKModule.Type
            else {
                return nil
            }

            AirshipLogger.debug("Loading module \($0)")
            return moduleClass.load(withDependencies: dependencies)
        }

        return sdkModules
    }
}


fileprivate class LegacyActionsManifest: ActionsManifest, @unchecked Sendable {
    let manifest: [[String] : () -> ActionEntry]

    init(actions: [UALegacyAction]) {

        var mapped: [[String] : () -> ActionEntry] = [:]

        actions.forEach { action in
            var predicate: (@Sendable (ActionArguments) async -> Bool)? = nil
            if let actionPredicate = action.defaultPredicate {
                predicate = { args in
                    return actionPredicate(args.value.unWrap(), args.situation.rawValue)
                }
            }
            
            mapped[action.defaultNames] = {
                ActionEntry(
                    action: LegacyActionAdapter(action: action),
                    predicate: predicate
                )
            }
        }

        self.manifest = mapped
    }
}


fileprivate class LegacyActionAdapter: AirshipAction, @unchecked Sendable {
    private let action: UALegacyAction

    init(action: UALegacyAction) {
        self.action = action
    }

    @MainActor
    func accepts(arguments: ActionArguments) async -> Bool {
        return action.acceptsArgumentValue(
            arguments.value.unWrap(),
            situation: arguments.situation.rawValue
        )
    }

    @MainActor
    func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        await withCheckedContinuation { continuation in

            let push = (arguments.metadata[ActionArguments.pushPayloadJSONMetadataKey] as? AirshipJSON)?.unWrap()
            action.perform(
                withArgumentValue: arguments.value.unWrap(),
                situation: arguments.situation.rawValue,
                pushUserInfo: push as? [AnyHashable : Any]
            ) {
                continuation.resume()
            }
        }

        return nil
    }
}
