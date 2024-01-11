/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


public class AutomationSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: ActionsManifest? = nil
    public let components: [AirshipComponent] = []

    public static func load(dependencies: [String : Any]) -> AirshipSDKModule? {

        // Dependencies
        let dataStore = dependencies[SDKDependencyKeys.dataStore] as! PreferenceDataStore
        let privacyManager = dependencies[SDKDependencyKeys.privacyManager] as! AirshipPrivacyManager
        let remoteData = dependencies[SDKDependencyKeys.remoteData] as! RemoteDataProtocol
        let deferredResolver = dependencies[SDKDependencyKeys.deferredResolver] as! AirshipDeferredResolverProtocol
        let config = dependencies[SDKDependencyKeys.config] as! RuntimeConfig
        let experiments = dependencies[SDKDependencyKeys.experimentsProvider] as! ExperimentDataProvider
        let sceneManager = dependencies[SDKDependencyKeys.sceneManager] as! AirshipSceneManagerProtocol
        let messageSceneManager = InAppMessageSceneManager(sceneManger: sceneManager)

        /// Utils
        let remoteDataAccess = AutomationRemoteDataAccess(remoteData: remoteData)
        let assetManager = AssetCacheManager()
        let displayCoordinatorManager = DisplayCoordinatorManager(dataStore: dataStore)
        let frequencyLimits = FrequencyLimitManager(config: config)
        let conditionsChangedNotifier = Notifier()

        /// Preperation
        let actionPreparer = ActionAutomationPreparer()
        let messagePreparer = InAppMessageAutomationPreparer(
            assetManager: assetManager,
            displayCoordinatorManager: displayCoordinatorManager
        )
        let automationPreparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess
        )

        // Execution
        let actionExecutor = ActionAutomationExecutor()
        let messageExecutor = InAppMessageAutomationExecutor(
            sceneManager: messageSceneManager,
            assetManager: assetManager,
            conditionsChangedNotifier: conditionsChangedNotifier
        )
        let automationExecutor = AutomationExecutor(
            actionExecutor: actionExecutor,
            messageExecutor: messageExecutor,
            remoteDataAccess: remoteDataAccess
        )

        // Engine
        let engine = AutomationEngine(
            executor: automationExecutor,
            preparer: automationPreparer,
            conditionsChangedNotifier: conditionsChangedNotifier
        )

        let remoteDataSchduler = AutomationRemoteDataScheduler(
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits
        )

        let inAppMessaging = InAppMessaging(
            executor: messageExecutor,
            preparer: messagePreparer
        )

        let _ = InAppAutomation(
            engine: engine,
            inAppMessaging: inAppMessaging,
            remoteDataScheduler: remoteDataSchduler,
            dataStore: dataStore,
            privacyManager: privacyManager,
            config: config
        )

        return nil
    }
}
