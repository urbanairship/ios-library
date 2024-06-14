/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


/// NOTE: For internal use only. :nodoc:
@objc(UAAutomationSDKModule)
public class AutomationSDKModule: NSObject, AirshipSDKModule {
    public let components: [AirshipComponent]
    public let actionsManifest: ActionsManifest? = AutomationActionManifest()

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
        let airshipAnalytics = dependencies[SDKDependencyKeys.analytics] as! InternalAnalyticsProtocol
        let meteredUsage = dependencies[SDKDependencyKeys.meteredUsage] as! AirshipMeteredUsageProtocol
        let cache = dependencies[SDKDependencyKeys.cache] as! AirshipCache

        /// Utils
        let remoteDataAccess = AutomationRemoteDataAccess(remoteData: remoteData)
        let assetManager = AssetCacheManager()
        let displayCoordinatorManager = DisplayCoordinatorManager(dataStore: dataStore)
        let frequencyLimits = FrequencyLimitManager(config: config)
        let scheduleConditionsChangedNotifier = ScheduleConditionsChangedNotifier()
        let eventRecorder = InAppEventRecorder(airshipAnalytics: airshipAnalytics, meteredUsage: meteredUsage)
        let metrics = ApplicationMetrics(dataStore: dataStore, privacyManager: privacyManager)

        let automationStore = AutomationStore(config: config)

        let analyticsFactory = InAppMessageAnalyticsFactory(
            eventRecorder: eventRecorder,
            displayHistoryStore: MessageDisplayHistoryStore(store: automationStore),
            displayImpressionRuleProvider: DefaultInAppDisplayImpressionRuleProvider()
        )

        /// Preperation
        let actionPreparer = ActionAutomationPreparer()
        let messagePreparer = InAppMessageAutomationPreparer(
            assetManager: assetManager,
            displayCoordinatorManager: displayCoordinatorManager,
            analyticsFactory: analyticsFactory
        )
        let automationPreparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess,
            config: config,
            additionalAudienceResolver: AdditionalAudienceCheckerResolver(
                config: config,
                cache: cache
            )
        )


        // Execution
        let actionExecutor = ActionAutomationExecutor()
        let messageExecutor = InAppMessageAutomationExecutor(
            sceneManager: messageSceneManager,
            assetManager: assetManager,
            analyticsFactory: analyticsFactory,
            scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier
        )
        
        let automationExecutor = AutomationExecutor(
            actionExecutor: actionExecutor,
            messageExecutor: messageExecutor,
            remoteDataAccess: remoteDataAccess
        )

        let feed = AutomationEventFeed(
            applicationMetrics: metrics,
            applicationStateTracker: AppStateTracker.shared,
            analyticsFeed: airshipAnalytics.eventFeed
        )
        feed.attach()

        // Engine
        let engine = AutomationEngine(
            store: automationStore,
            executor: automationExecutor,
            preparer: automationPreparer,
            scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier,
            eventFeed: feed,
            triggersProcessor: AutomationTriggerProcessor(store: automationStore),
            delayProcessor: AutomationDelayProcessor(analytics: airshipAnalytics)
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
            analytics: LegacyInAppAnalytics(recorder: eventRecorder),
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

        return AutomationSDKModule(
            components: [
                InAppAutomationComponent(inAppAutomation: inAppAutomation)
            ]
        )
    }
}

fileprivate struct AutomationActionManifest : ActionsManifest {
    var manifest: [[String] : () -> ActionEntry] = [
        LandingPageAction.defaultNames: {
            return ActionEntry(
                action: LandingPageAction()
            )
        }
    ]
}
