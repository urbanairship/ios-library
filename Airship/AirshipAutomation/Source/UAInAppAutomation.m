/* Copyright Airship and Contributors */

#import "UAInAppAutomation+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UATagSelector+Internal.h"
#import "UARetriable+Internal.h"
#import "UARetriablePipeline+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAScheduleAudience+Internal.h"
#import "UAInAppMessageSchedule.h"
#import "UADeferredScheduleRetryRules+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

static NSTimeInterval const MaxSchedules = 1000;
static NSString *const UAInAppMessageManagerPausedKey = @"UAInAppMessageManagerPaused";
static NSString * const UAAutomationEnginePrepareScheduleEvent = @"com.urbanairship.automation.prepare_schedule";
static NSString *const UADefaultScheduleMessageType = @"transactional";

@interface UAInAppAutomation () <UAAutomationEngineDelegate, UAInAppRemoteDataClientDelegate, UAInAppMessagingExecutionDelegate>
@property(nonatomic, strong) UAAutomationEngine *automationEngine;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAAutomationAudienceOverridesProvider *audienceOverridesProvider;
@property(nonatomic, strong) UAInAppRemoteDataClient *remoteDataClient;
@property(nonatomic, strong) UARetriablePipeline *prepareSchedulePipeline;
@property(nonatomic, strong) UAInAppMessageManager *inAppMessageManager;
@property(nonatomic, strong) UADeferredScheduleAPIClient *deferredScheduleAPIClient;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAFrequencyLimitManager *frequencyLimitManager;
@property(nonatomic) id<UAExperimentDataProvider> experimentManager;
@property(nonatomic, strong) NSMutableDictionary<NSString *, UAFrequencyChecker *> *frequencyCheckers;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, assign) dispatch_once_t engineStarted;
@property(nonatomic, strong) UAComponentDisableHelper *disableHelper;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *redirectURLs;
@property(nonatomic, strong) id<UAAutomationAudienceCheckerProtocol> audienceChecker;

@end

@implementation UAInAppAutomation

+ (UAInAppAutomation *)shared {
    return (UAInAppAutomation *)[UAirship componentForClassName:NSStringFromClass([self class])];
}


+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                    automationEngine:(UAAutomationEngine *)automationEngine
           audienceOverridesProvider:(UAAutomationAudienceOverridesProvider *)audienceOverridesProvider
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                 inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                             channel:(UAChannel *)channel
           deferredScheduleAPIClient:(UADeferredScheduleAPIClient *)deferredScheduleAPIClient
               frequencyLimitManager:(UAFrequencyLimitManager *)frequencyLimitManager
                      privacyManager:(UAPrivacyManager *)privacyManager
                   experimentManager:(id<UAExperimentDataProvider>) experimentManager
                     audienceChecker:(id <UAAutomationAudienceCheckerProtocol>)audienceChecker {


    return [[self alloc] initWithConfig:config
                       automationEngine:automationEngine
              audienceOverridesProvider:audienceOverridesProvider
                       remoteDataClient:remoteDataClient
                              dataStore:dataStore
                    inAppMessageManager:inAppMessageManager
                                channel:channel
              deferredScheduleAPIClient:deferredScheduleAPIClient
                  frequencyLimitManager:frequencyLimitManager
                         privacyManager:privacyManager
                     experimentsManager:experimentManager
                        audienceChecker:audienceChecker];
}

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
           audienceOverridesProvider:(UAAutomationAudienceOverridesProvider *)audienceOverridesProvider
                          remoteData:(UARemoteDataAutomationAccess *)remoteData
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics
                      privacyManager:(UAPrivacyManager *)privacyManager
                  experimentManager: (id<UAExperimentDataProvider>) experimentManager {


    UAAutomationStore *store = [UAAutomationStore automationStoreWithConfig:config
                                                              scheduleLimit:MaxSchedules];

    UAAutomationEngine *automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:store];

    UAInAppRemoteDataClient *dataClient = [UAInAppRemoteDataClient clientWithRemoteData:remoteData
                                                                              dataStore:dataStore
                                                                                channel:channel];

    UAInAppMessageManager *inAppMessageManager = [UAInAppMessageManager managerWithDataStore:dataStore
                                                                                   analytics:analytics];

    UADeferredScheduleAPIClient *deferredScheduleAPIClient = [UADeferredScheduleAPIClient clientWithConfig:config];

    UAFrequencyLimitManager *frequencyLimitManager = [UAFrequencyLimitManager managerWithConfig:config];

    return [[UAInAppAutomation alloc] initWithConfig:config
                                    automationEngine:automationEngine
                           audienceOverridesProvider:audienceOverridesProvider
                                    remoteDataClient:dataClient
                                           dataStore:dataStore
                                 inAppMessageManager:inAppMessageManager
                                             channel:channel
                           deferredScheduleAPIClient:deferredScheduleAPIClient
                               frequencyLimitManager:frequencyLimitManager
                                      privacyManager:privacyManager
                                  experimentsManager:experimentManager
                                     audienceChecker:[[UAAutomationAudienceChecker alloc] init]];
}


- (instancetype)initWithConfig:(UARuntimeConfig *)config
              automationEngine:(UAAutomationEngine *)automationEngine
     audienceOverridesProvider:(UAAutomationAudienceOverridesProvider *)audienceOverridesProvider
              remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                     dataStore:(UAPreferenceDataStore *)dataStore
           inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                       channel:(UAChannel *)channel
     deferredScheduleAPIClient:(UADeferredScheduleAPIClient *)deferredScheduleAPIClient
         frequencyLimitManager:(UAFrequencyLimitManager *)frequencyLimitManager
                privacyManager:(UAPrivacyManager *)privacyManager
            experimentsManager:(id<UAExperimentDataProvider>) experimentManager
               audienceChecker:(id <UAAutomationAudienceCheckerProtocol>)audienceChecker {

    self = [super init];

    if (self) {
        self.automationEngine = automationEngine;
        self.audienceOverridesProvider = audienceOverridesProvider;
        self.remoteDataClient = remoteDataClient;
        self.dataStore = dataStore;
        self.inAppMessageManager = inAppMessageManager;
        self.channel = channel;
        self.deferredScheduleAPIClient = deferredScheduleAPIClient;
        self.frequencyLimitManager = frequencyLimitManager;
        self.prepareSchedulePipeline = [UARetriablePipeline pipeline];
        self.frequencyCheckers = [NSMutableDictionary dictionary];
        self.privacyManager = privacyManager;
        self.audienceChecker = audienceChecker;
        self.automationEngine.delegate = self;
        self.remoteDataClient.delegate = self;
        self.inAppMessageManager.executionDelegate = self;
        self.disableHelper = [[UAComponentDisableHelper alloc] initWithDataStore:dataStore
                                                                       className:@"UAInAppAutomation"];
        self.redirectURLs = [NSMutableDictionary dictionary];
        self.experimentManager = experimentManager;

        UA_WEAKIFY(self)
        self.disableHelper.onChange = ^{
            UA_STRONGIFY(self)
            [self onComponentEnableChange];
        };

        if (config.autoPauseInAppAutomationOnLaunch) {
            self.paused = YES;
        }
    }

    return self;
}

- (void)airshipReady {
    // Update in-app automation when enabled features change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onEnabledFeaturesChanged)
                                                 name:UAPrivacyManager.changeEvent
                                               object:nil];


    [self updateSubscription];
    [self updateEnginePauseState];
}

- (void)getMessageScheduleWithID:(NSString *)identifier
               completionHandler:(void (^)(UAInAppMessageSchedule *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getScheduleWithID:identifier
                                        type:UAScheduleTypeInAppMessage
                           completionHandler:^(UASchedule *schedule) {
        completionHandler((UAInAppMessageSchedule *)schedule);
    }];
}

- (void)getMessageSchedulesWithGroup:(NSString *)group
                   completionHandler:(void (^)(NSArray<UAInAppMessageSchedule *> *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getSchedulesWithGroup:group
                                            type:UAScheduleTypeInAppMessage
                               completionHandler:completionHandler];
}

- (void)getMessageSchedules:(void (^)(NSArray<UAInAppMessageSchedule *> *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getSchedulesWithType:UAScheduleTypeInAppMessage completionHandler:completionHandler];
}

- (void)getActionScheduleWithID:(NSString *)identifier
              completionHandler:(void (^)(UAActionSchedule *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getScheduleWithID:identifier
                                        type:UAScheduleTypeActions
                           completionHandler:^(UASchedule *schedule) {
        if (completionHandler) {
            completionHandler((UAActionSchedule *)schedule);
        }
    }];
}

- (void)getActionSchedulesWithGroup:(NSString *)group
                  completionHandler:(void (^)(NSArray<UAActionSchedule *> *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getSchedulesWithGroup:group
                                            type:UAScheduleTypeActions
                               completionHandler:completionHandler];
}

- (void)getActionSchedules:(void (^)(NSArray<UAActionSchedule *> *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getSchedulesWithType:UAScheduleTypeActions completionHandler:completionHandler];
}

- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine getSchedules:completionHandler];
}

- (void)schedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine schedule:schedule completionHandler:completionHandler];
}

- (void)scheduleMultiple:(NSArray<UASchedule *> *)schedules completionHandler:(void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine scheduleMultiple:schedules completionHandler:completionHandler];
}

- (void)cancelScheduleWithID:(NSString *)scheduleID
           completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine cancelScheduleWithID:scheduleID completionHandler:completionHandler];
}

- (void)cancelSchedulesWithType:(UAScheduleType)scheduleType
              completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine cancelSchedulesWithType:scheduleType completionHandler:completionHandler];
}

- (void)cancelSchedulesWithGroup:(NSString *)group
               completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine cancelSchedulesWithGroup:group completionHandler:completionHandler];
}

- (void)cancelMessageSchedulesWithGroup:(NSString *)group
                      completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine cancelSchedulesWithGroup:group
                                               type:UAScheduleTypeInAppMessage
                                  completionHandler:completionHandler];
}

- (void)cancelActionSchedulesWithGroup:(NSString *)group
                     completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine cancelSchedulesWithGroup:group
                                               type:UAScheduleTypeActions
                                  completionHandler:completionHandler];
}


- (void)editScheduleWithID:(NSString *)scheduleID
                     edits:(UAScheduleEdits *)edits
         completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self ensureEngineStarted];
    [self.automationEngine editScheduleWithID:scheduleID edits:edits completionHandler:completionHandler];
}

- (void)prepareSchedule:(UASchedule *)schedule
         triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
      completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {

    UA_LDEBUG(@"Trigger Context trigger: %@ event: %@", triggerContext.trigger, triggerContext.event);
    UA_LDEBUG(@"Preparing schedule: %@", schedule.identifier);
    
    NSString *scheduleID = schedule.identifier;

    // Check valid
    UA_WEAKIFY(self)
    UARetriable *checkValid = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)
        [self.remoteDataClient refreshAndCheckScheduleUpToDate:schedule completionHandler:^(BOOL isValid) {
            if (isValid) {
                retriableHandler(UARetriableResultSuccess, 0);
            } else {
                completionHandler(UAAutomationSchedulePrepareResultInvalidate);
                retriableHandler(UARetriableResultInvalidate, 0);
            }
        }];
    }];


    __block UAFrequencyChecker *checker;
    UARetriable *checkFrequencyLimits = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler retriableHandler) {
        [self.frequencyLimitManager getFrequencyChecker:schedule.frequencyConstraintIDs completionHandler:^(UAFrequencyChecker *c) {
            checker = c;
            if (checker.isOverLimit) {
                // If we're over the limit, skip the rest of the prepare steps and invalidate the pipeline
                completionHandler(UAAutomationSchedulePrepareResultSkip);
                retriableHandler(UARetriableResultInvalidate, 0);
            } else {
                retriableHandler(UARetriableResultSuccess, 0);
            }
        }];
    }];

    // Check audience conditions
    UARetriable *checkAudience = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        [self checkAudienceForSchedule:schedule completionHandler:^(BOOL success, NSError *error) {
            if (error) {
                retriableHandler(UARetriableResultRetry, 0);
            } else if (success) {
                retriableHandler(UARetriableResultSuccess, 0);
            } else {
                UAScheduleAudienceMissBehaviorType missBehavior = schedule.audienceMissBehavior;
                UA_LDEBUG(@"Message audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", scheduleID, (long)missBehavior);
                completionHandler([UAInAppAutomation prepareResultForMissedBehavior:missBehavior]);
                retriableHandler(UARetriableResultCancel, 0);
            }
        }];
    }];

    void (^prepareCompletionHandlerWrapper)(UAAutomationSchedulePrepareResult) = ^(UAAutomationSchedulePrepareResult result){
        UA_STRONGIFY(self)
        if (checker && result == UAAutomationSchedulePrepareResultContinue) {
            [self.frequencyCheckers setObject:checker forKey:scheduleID];
        }
        completionHandler(result);
    };

    // Evaluate experiements
    __block UAExperimentResult *experimentResult;
    UARetriable *evaluateExperiments = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)
        [self evaluateExperimentsForSchedule:schedule completionHandler:^(UAExperimentResult *result, NSError *error) {
            if (error) {
                UA_LDEBUG(@"Error %@ evaluating experiments for schedule: %@", error, scheduleID);
                retriableHandler(UARetriableResultRetry, 0);
            } else {
                UA_LDEBUG(@"Experiment result %@ for schedule: %@", result, scheduleID);
                experimentResult = result;
                retriableHandler(UARetriableResultSuccess, 0);
            }
        }];
    }];

    // Prepare
    UARetriable *prepare = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)

        switch (schedule.type) {
            case UAScheduleTypeActions:
                prepareCompletionHandlerWrapper(UAAutomationSchedulePrepareResultContinue);
                retriableHandler(UARetriableResultSuccess, 0);
                break;

            case UAScheduleTypeInAppMessage:
                [self.inAppMessageManager prepareMessage:(UAInAppMessage *)schedule.data
                                              scheduleID:schedule.identifier
                                               campaigns:schedule.campaigns
                                        reportingContext:schedule.reportingContext
                                        experimentResult:experimentResult
                                       completionHandler:prepareCompletionHandlerWrapper];
                retriableHandler(UARetriableResultSuccess, 0);
                break;

            case UAScheduleTypeDeferred:
                [self prepareDeferredSchedule:schedule
                               triggerContext:triggerContext
                             experimentResult:experimentResult
                             retriableHandler:retriableHandler
                            completionHandler:prepareCompletionHandlerWrapper];
                break;


            default:
                UA_LERR(@"Unexpected schedule type: %ld", schedule.type);
                retriableHandler(UARetriableResultSuccess, 0);
        }
    }];


    [self.prepareSchedulePipeline addChainedRetriables:@[
        checkValid,
        checkFrequencyLimits,
        checkAudience,
        evaluateExperiments,
        prepare
    ]];
}

- (void)prepareDeferredSchedule:(UASchedule *)schedule
                 triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
               experimentResult:(UAExperimentResult *)experimentResult
               retriableHandler:(UARetriableCompletionHandler) retriableHandler
              completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {

    UAScheduleDeferredData *deferred =  (UAScheduleDeferredData *)schedule.data;
    NSString *channelID = self.channel.identifier;
    if (!channelID) {
        retriableHandler(UARetriableResultRetry, 0);
        return;
    }

    NSURL *url = [self.redirectURLs valueForKey:schedule.identifier] ?: deferred.URL;



    [self.audienceOverridesProvider audienceOverridesWithChannelID:channelID
                                                 completionHandler:^(UAAutomationAudienceOverrides *audienceOverrides) {

        [self.deferredScheduleAPIClient resolveURL:url
                                         channelID:channelID
                                    triggerContext:triggerContext
                                 audienceOverrides:audienceOverrides
                                 completionHandler:^(UADeferredAPIClientResponse *response, NSError *error) {
            if (error) {
                if (deferred.retriableOnTimeout) {
                    retriableHandler(UARetriableResultRetry, 0);
                } else {
                    retriableHandler(UARetriableResultSuccess, 0);
                    completionHandler(UAAutomationSchedulePrepareResultPenalize);
                }
            } else if (response.result) {
                if (!response.result.isAudienceMatch) {
                    UA_LDEBUG(@"Audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", schedule.identifier, (long)schedule.audience.missBehavior);
                    completionHandler([UAInAppAutomation prepareResultForMissedBehavior:schedule.audienceMissBehavior]);
                    retriableHandler(UARetriableResultCancel, 0);
                } else if (response.result.message) {
                    [self.inAppMessageManager prepareMessage:response.result.message
                                                  scheduleID:schedule.identifier
                                                   campaigns:schedule.campaigns
                                            reportingContext:schedule.reportingContext
                                            experimentResult:experimentResult
                                           completionHandler:completionHandler];
                    retriableHandler(UARetriableResultSuccess, 0);
                } else {
                    completionHandler(UAAutomationSchedulePrepareResultPenalize);
                    retriableHandler(UARetriableResultSuccess, 0);
                }
            } else {
                switch (response.status) {
                    case 307: {
                        if (response.rules.location) {
                            [self.redirectURLs setValue:[NSURL URLWithString:response.rules.location] forKey:schedule.identifier];
                        }
                        if (response.rules.retryTime) {
                            NSTimeInterval backoff = response.rules.retryTime;
                            retriableHandler(UARetriableResultRetryAfter, backoff);
                        } else {
                            retriableHandler(UARetriableResultRetryWithBackoffReset, 0);
                        }
                        break;
                    }
                    case 401: {
                        retriableHandler(UARetriableResultRetry, 0);
                        break;
                    }
                    case 409: {
                        [self.remoteDataClient invalidateAndRefreshSchedule:schedule completionHandler:^{
                            completionHandler(UAAutomationSchedulePrepareResultInvalidate);
                        }];
                        retriableHandler(UARetriableResultCancel, 0);
                        break;
                    }
                    case 429: {
                        if (response.rules.location) {
                            [self.redirectURLs setValue:[NSURL URLWithString:response.rules.location] forKey:schedule.identifier];

                        }
                        if (response.rules.retryTime) {
                            NSTimeInterval backoff = response.rules.retryTime;
                            retriableHandler(UARetriableResultRetryAfter, backoff);
                        } else {
                            retriableHandler(UARetriableResultRetry, 0);
                        }

                        break;
                    }
                    default:
                        retriableHandler(UARetriableResultRetry, 0);
                        break;
                }
            }
        }];
    }];

}

+ (UAAutomationSchedulePrepareResult)prepareResultForMissedBehavior:(UAScheduleAudienceMissBehaviorType)missBehavior {
    switch(missBehavior) {
        case UAScheduleAudienceMissBehaviorCancel:
            return UAAutomationSchedulePrepareResultCancel;
        case UAScheduleAudienceMissBehaviorSkip:
            return UAAutomationSchedulePrepareResultSkip;
        case UAScheduleAudienceMissBehaviorPenalize:
            return UAAutomationSchedulePrepareResultPenalize;
    }
}

- (UAAutomationScheduleReadyResult)isScheduleReadyToExecute:(UASchedule *)schedule {
    UA_LTRACE(@"Checking if schedule %@ is ready to execute.", schedule.identifier);

    if (self.isPaused) {
        UA_LTRACE(@"InAppAutoamtion currently paused. Schedule: %@ not ready.", schedule.identifier);
        return UAAutomationScheduleReadyResultNotReady;
    }

    switch (schedule.type) {
        case UAScheduleTypeDeferred:
        case UAScheduleTypeInAppMessage: {
            UAAutomationScheduleReadyResult result = [self.inAppMessageManager isReadyToDisplay:schedule.identifier];
            if (result != UAAutomationScheduleReadyResultContinue) {
                return result;
            }
        }
        case UAScheduleTypeActions:
        default:
            break;
    }

    UAFrequencyChecker *checker = self.frequencyCheckers[schedule.identifier];
    if (checker && !checker.checkAndIncrement) {
        // Abort execution if necessary and skip
        if (schedule.type == UAScheduleTypeInAppMessage) {
            [self.inAppMessageManager scheduleExecutionAborted:schedule.identifier];
        }
        return UAAutomationScheduleReadyResultSkip;
    }

    return UAAutomationScheduleReadyResultContinue;
}

- (void)executeSchedule:(nonnull UASchedule *)schedule completionHandler:(void (^)(void))completionHandler {
    UA_LTRACE(@"Executing schedule: %@", schedule.identifier);

    [self.frequencyCheckers removeObjectForKey:schedule.identifier];

    switch (schedule.type) {
        case UAScheduleTypeActions: {
            // Run the actions
            [UAActionRunner runActions:schedule.data
                      situation:UAActionSituationAutomation
              completionHandler:completionHandler];
            break;
        }

        case UAScheduleTypeDeferred:
        case UAScheduleTypeInAppMessage: {
            [self.inAppMessageManager displayMessageWithScheduleID:schedule.identifier completionHandler:completionHandler];
            break;
        }

        default: {
            UA_LERR(@"Unexpected schedule type: %ld", schedule.type);
            return completionHandler();
        }
    }
}

- (void)onExecutionInterrupted:(UASchedule *)schedule {
    switch (schedule.type) {
        case UAScheduleTypeActions: {
            break;
        }

        case UAScheduleTypeInAppMessage: {
            [self.inAppMessageManager messageExecutionInterrupted:schedule.data
                                                       scheduleID:schedule.identifier
                                                        campaigns:schedule.campaigns
                                                 reportingContext:schedule.reportingContext];
            break;
        }

        case UAScheduleTypeDeferred: {
            UAScheduleDeferredData *deferred = schedule.data;
            if (deferred.type == UAScheduleDataDeferredTypeInAppMessage) {
                [self.inAppMessageManager messageExecutionInterrupted:nil
                                                           scheduleID:schedule.identifier
                                                            campaigns:schedule.campaigns
                                                     reportingContext:schedule.reportingContext];
            }
            break;
        }
    }
}

- (void)onScheduleExpired:(UASchedule *)schedule {
    if (schedule.type == UAScheduleTypeInAppMessage) {
        [self.inAppMessageManager messageExpired:(UAInAppMessage *)schedule.data
                                      scheduleID:schedule.identifier
                                  expirationDate:schedule.end];
    }
}

- (void)onScheduleCancelled:(UASchedule *)schedule {
    if (schedule.type == UAScheduleTypeInAppMessage) {
        [self.inAppMessageManager messageCancelled:(UAInAppMessage *)schedule.data
                                        scheduleID:schedule.identifier];
    }
}

- (void)onScheduleLimitReached:(UASchedule *)schedule {
    if (schedule.type == UAScheduleTypeInAppMessage) {
        [self.inAppMessageManager messageLimitReached:(UAInAppMessage *)schedule.data
                                           scheduleID:schedule.identifier];
    }
}

- (void)onNewSchedule:(nonnull UASchedule *)schedule {
    if (schedule.type == UAScheduleTypeInAppMessage) {
        [self.inAppMessageManager messageScheduled:(UAInAppMessage *)schedule.data
                                        scheduleID:schedule.identifier];
    }
}

- (void)isScheduleReadyPrecheck:(nonnull UASchedule *)schedule
              completionHandler:(nonnull void (^)(UAAutomationScheduleReadyResult))completionHandler {
    [self.remoteDataClient isScheduleUpToDate:schedule completionHandler:^(BOOL result) {
        if (result) {
            completionHandler(UAAutomationScheduleReadyResultContinue);
        } else {
            if (schedule.type == UAScheduleTypeInAppMessage) {
                [self.inAppMessageManager scheduleExecutionAborted:schedule.identifier];
            }
            completionHandler(UAAutomationScheduleReadyResultInvalidate);
        }
    }];
}


- (BOOL)isComponentEnabled {
    return self.disableHelper.enabled;
}

- (void)setComponentEnabled:(BOOL)componentEnabled {
    self.disableHelper.enabled = componentEnabled;
}

- (void)onComponentEnableChange {
    [self updateEnginePauseState];
}

- (void)updateConstraints:(NSArray<UAFrequencyConstraint *> *)constraints {
     [self.frequencyLimitManager updateConstraints:constraints];
}

- (void)setPaused:(BOOL)paused {
    [self.dataStore setBool:paused forKey:UAInAppMessageManagerPausedKey];
    [self updateEnginePauseState];
    if (!paused) {
        [self.automationEngine scheduleConditionsChanged];
    }
}

- (BOOL)isPaused{
    return [self.dataStore boolForKey:UAInAppMessageManagerPausedKey defaultValue:NO];
}

- (void)dealloc {
    [self.automationEngine stop];
    [self.remoteDataClient unsubscribe];
    self.automationEngine.delegate = nil;
}

- (void)checkAudienceForSchedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    if (schedule.audienceJSON) {

        UARemoteDataInfo *remoteDataInfo = [self.remoteDataClient remoteDataInfoFromSchedule:schedule];

        [self.audienceChecker evaluateWithAudience:schedule.audienceJSON
                             isNewUserEvaluationDate:schedule.isNewUserEvaluationDate ?: [NSDate distantPast]
                                         contactID:remoteDataInfo.contactID
                                 completionHandler:completionHandler];
    }  else {
        completionHandler(YES, nil);
    }
}

// Internal method that was in a public header, should delete next major release
// Keeping it functional to avoid breaking anyone that is using an internally documented method.
- (void)checkAudience:(UAScheduleAudience *)audience completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    [self.audienceChecker evaluateWithAudience:[audience toJSON]
                       isNewUserEvaluationDate:[NSDate date]
                                     contactID:nil
                             completionHandler:completionHandler];
}

- (void)executionReadinessChanged {
    [self.automationEngine scheduleConditionsChanged];
}

- (void)cancelScheduleWithID:(nonnull NSString *)scheduleID {
    [self ensureEngineStarted];
    [self.automationEngine cancelScheduleWithID:scheduleID completionHandler:nil];
}

- (void)onEnabledFeaturesChanged {
    [self updateSubscription];
    [self updateEnginePauseState];
}

- (void)updateEnginePauseState {
    if (self.componentEnabled && [self.privacyManager isEnabled:UAFeaturesInAppAutomation]) {
        [self.automationEngine resume];
    } else {
        [self.automationEngine pause];
    }
}

- (void)updateSubscription {
    @synchronized (self.remoteDataClient) {
        if ([self.privacyManager isEnabled:UAFeaturesInAppAutomation]) {
            [self ensureEngineStarted];
            [self.remoteDataClient subscribe];
        } else {
            [self.remoteDataClient unsubscribe];
        }
    }
}

- (void)ensureEngineStarted {
    dispatch_once(&_engineStarted, ^{
        [self.automationEngine start];
    });
}

#pragma mark - Holdout groups
- (void)evaluateExperimentsForSchedule:(UASchedule *)schedule
                     completionHandler:(void (^)(UAExperimentResult *, NSError *))completionHandler {

    UARemoteDataInfo *remoteDataInfo = [self.remoteDataClient remoteDataInfoFromSchedule:schedule];

    // Skip actions for now or anything that is not from remote-data
    if (schedule.type == UAScheduleTypeActions || !remoteDataInfo) {
        completionHandler(nil, nil);
        return;
    }

    if (schedule.bypassHoldoutGroups) {
        completionHandler(nil, nil);
    } else {
        UAExperimentMessageInfo *info = [[UAExperimentMessageInfo alloc] initWithMessageType:schedule.messageType ?: UADefaultScheduleMessageType
                                                                               campaignsJSON:schedule.campaigns];
        [self.experimentManager evaluateExperimentsWithInfo:info
                                                  contactID:remoteDataInfo.contactID
                                          completionHandler:completionHandler];
    }
}

@end
