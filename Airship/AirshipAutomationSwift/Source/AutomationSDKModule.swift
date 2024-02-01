/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


@objc(UAAutomationSDKModule)
public class AutomationSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: ActionsManifest? = nil
    public let components: [AirshipComponent]

    init(components: [AirshipComponent]) {
        self.components = components
    }
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
        let analytics = dependencies[SDKDependencyKeys.analytics] as! InternalAnalyticsProtocol
        let meteredUsage = dependencies[SDKDependencyKeys.meteredUsage] as! AirshipMeteredUsageProtocol
        let metrics = dependencies[SDKDependencyKeys.applicationMetrics] as! ApplicationMetrics

        /// Utils
        let remoteDataAccess = AutomationRemoteDataAccess(remoteData: remoteData)
        let assetManager = AssetCacheManager()
        let displayCoordinatorManager = DisplayCoordinatorManager(dataStore: dataStore)
        let frequencyLimits = FrequencyLimitManager(config: config)
        let scheduleConditionsChangedNotifier = ScheduleConditionsChangedNotifier()

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
            analyticsFactory: InAppMessageAnalyticsFactory(analytics: analytics, meteredUsage: meteredUsage),
            scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier
        )
        
        let automationExecutor = AutomationExecutor(
            actionExecutor: actionExecutor,
            messageExecutor: messageExecutor,
            remoteDataAccess: remoteDataAccess
        )

        let feed = AutomationEventFeed(metrics:  metrics)
        feed.attach()

        // Engine
        let engine = AutomationEngine(
            store: AutomationStore(config: config),
            executor: automationExecutor,
            preparer: automationPreparer,
            scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier,
            eventFeed: feed,
            triggersProcessor: AutomationTriggerProcessor(),
            delayProcessor: AutomationDelayProcessor(analytics: analytics)
        )

        let remoteDataSubscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits
        )

        let inAppMessaging = InAppMessaging(
            executor: messageExecutor,
            preparer: messagePreparer
        )

        let legacyInAppMessaging = LegacyInAppMessaging(
            analytics: LegacyInAppAnalytics(recorder: InAppEventRecorder(analytics: analytics)),
            dataStore: dataStore,
            automationEngine: engine
        )

        let inAppAutomation = InAppAutomation(
            engine: engine,
            inAppMessaging: inAppMessaging,
            legacyInAppMessaging: legacyInAppMessaging,
            remoteDataSubscriber: remoteDataSubscriber,
            dataStore: dataStore,
            privacyManager: privacyManager,
            config: config
        )

        return AutomationSDKModule(components: [inAppAutomation])
    }
}
