/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
public import AirshipCore
#endif

import Foundation

/// NOTE: For internal use only. :nodoc:
@objc(UAAutomationSDKModule)
public class AutomationSDKModule: NSObject, AirshipSDKModule {
    public let components: [any AirshipComponent]
    public let actionsManifest: (any ActionsManifest)? = AutomationActionManifest()

    init(components: [any AirshipComponent]) {
        self.components = components
    }

    public static func load(_ args: AirshiopModuleLoaderArgs) -> (any AirshipSDKModule)? {
        /// Utils
        let messageSceneManager = InAppMessageSceneManager(sceneManger: AirshipSceneManager.shared)
        let remoteDataAccess = AutomationRemoteDataAccess(remoteData: args.remoteData)
        let assetManager = AssetCacheManager()
        let displayCoordinatorManager = DisplayCoordinatorManager(dataStore: args.dataStore)
        let frequencyLimits = FrequencyLimitManager(config: args.config)
        let scheduleConditionsChangedNotifier = ScheduleConditionsChangedNotifier()
        let eventRecorder = ThomasLayoutEventRecorder(airshipAnalytics: args.analytics, meteredUsage: args.meteredUsage)
        let metrics = ApplicationMetrics(dataStore: args.dataStore, privacyManager: args.privacyManager)

        let automationStore = AutomationStore(config: args.config)
        let history = DefaultAutomationEventsHistory()

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
            deferredResolver: args.deferredResolver,
            frequencyLimits: frequencyLimits,
            audienceChecker: args.audienceChecker,
            experiments: args.experimentsManager,
            remoteDataAccess: remoteDataAccess,
            config: args.config,
            additionalAudienceResolver: AdditionalAudienceCheckerResolver(
                config: args.config,
                cache: args.cache
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
            analyticsFeed: args.analytics.eventFeed
        )
        feed.attach()

        // Engine
        let engine = AutomationEngine(
            store: automationStore,
            executor: automationExecutor,
            preparer: automationPreparer,
            scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier,
            eventFeed: feed,
            triggersProcessor: AutomationTriggerProcessor(
                store: automationStore,
                history: history
            ),
            delayProcessor: AutomationDelayProcessor(analytics: args.analytics),
            eventsHistory: history,
        )

        let remoteDataSubscriber = AutomationRemoteDataSubscriber(
            dataStore: args.dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits
        )

        let inAppMessaging = DefaultInAppMessaging(
            executor: messageExecutor,
            preparer: messagePreparer
        )

        let legacyInAppMessaging = DefaultLegacyInAppMessaging(
            analytics: LegacyInAppAnalytics(recorder: eventRecorder),
            dataStore: args.dataStore,
            automationEngine: engine
        )

        let inAppAutomation = DefaultInAppAutomation(
            engine: engine,
            inAppMessaging: inAppMessaging,
            legacyInAppMessaging: legacyInAppMessaging,
            remoteData: args.remoteData,
            remoteDataSubscriber: remoteDataSubscriber,
            dataStore: args.dataStore,
            privacyManager: args.privacyManager,
            config: args.config
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
                action: LandingPageAction(),
                predicate: LandingPageAction.defaultPredicate
            )
        }
    ]
}
