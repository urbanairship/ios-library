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
#import "NSDictionary+UAAdditions+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

#define kUADeferredScheduleAPIClientAudienceMatchKey @"audience_match"
#define kUADeferredScheduleAPIClientResponseTypeKey @"type"
#define kUADeferredScheduleAPIClientMessageKey @"message"
#define kUADeferredScheduleAPIClientInAppMessageType @"in_app_message"

static NSTimeInterval const MaxSchedules = 1000;
static NSString *const UAInAppMessageManagerPausedKey = @"UAInAppMessageManagerPaused";
static NSString * const UAAutomationEnginePrepareScheduleEvent = @"com.urbanairship.automation.prepare_schedule";
static NSString *const UADefaultScheduleMessageType = @"transactional";

@interface UAInAppAutomation () <UAAutomationEngineDelegate, UAInAppRemoteDataClientDelegate, UAInAppMessagingExecutionDelegate>
@property(nonatomic, strong) UAAutomationEngine *automationEngine;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAInAppRemoteDataClient *remoteDataClient;
@property(nonatomic, strong) UAInAppCoreSwiftBridge *inAppCoreSwiftBridge;
@property(nonatomic, strong) UARetriablePipeline *prepareSchedulePipeline;
@property(nonatomic, strong) UAInAppMessageManager *inAppMessageManager;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAFrequencyLimitManager *frequencyLimitManager;
@property(nonatomic, strong) NSMutableDictionary<NSString *, UAFrequencyChecker *> *frequencyCheckers;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, assign) dispatch_once_t engineStarted;
@property(nonatomic, strong) UAComponentDisableHelper *disableHelper;
@property(nonatomic, strong) NSMutableDictionary<NSString *, UARemoteDataInfo *> *remoteDataInfoCache;
@end

@implementation UAInAppAutomation

+ (UAInAppAutomation *)shared {
    return (UAInAppAutomation *)[UAirship componentForClassName:NSStringFromClass([self class])];
}

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                    automationEngine:(UAAutomationEngine *)automationEngine
                inAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                 inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                             channel:(UAChannel *)channel
               frequencyLimitManager:(UAFrequencyLimitManager *)frequencyLimitManager
                      privacyManager:(UAPrivacyManager *)privacyManager {

    return [[self alloc] initWithConfig:config
                       automationEngine:automationEngine
                   inAppCoreSwiftBridge:inAppCoreSwiftBridge
                       remoteDataClient:remoteDataClient
                              dataStore:dataStore
                    inAppMessageManager:inAppMessageManager
                                channel:channel
                  frequencyLimitManager:frequencyLimitManager
                         privacyManager:privacyManager];
}

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                inAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics
                      privacyManager:(UAPrivacyManager *)privacyManager {


    UAAutomationStore *store = [UAAutomationStore automationStoreWithConfig:config
                                                              scheduleLimit:MaxSchedules];

    UAAutomationEngine *automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:store];

    UAInAppRemoteDataClient *dataClient = [UAInAppRemoteDataClient clientWithInAppCoreSwiftBridge:inAppCoreSwiftBridge
                                                                                        dataStore:dataStore
                                                                                          channel:channel];

    UAInAppMessageManager *inAppMessageManager = [UAInAppMessageManager managerWithDataStore:dataStore
                                                                                   analytics:analytics];


    UAFrequencyLimitManager *frequencyLimitManager = [UAFrequencyLimitManager managerWithConfig:config];

    return [[UAInAppAutomation alloc] initWithConfig:config
                                    automationEngine:automationEngine
                                inAppCoreSwiftBridge:inAppCoreSwiftBridge
                                    remoteDataClient:dataClient
                                           dataStore:dataStore
                                 inAppMessageManager:inAppMessageManager
                                             channel:channel
                               frequencyLimitManager:frequencyLimitManager
                                      privacyManager:privacyManager];
}


- (instancetype)initWithConfig:(UARuntimeConfig *)config
              automationEngine:(UAAutomationEngine *)automationEngine
          inAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
              remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                     dataStore:(UAPreferenceDataStore *)dataStore
           inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                       channel:(UAChannel *)channel
         frequencyLimitManager:(UAFrequencyLimitManager *)frequencyLimitManager
                privacyManager:(UAPrivacyManager *)privacyManager {

    self = [super init];

    if (self) {
        self.automationEngine = automationEngine;
        self.inAppCoreSwiftBridge = inAppCoreSwiftBridge;
        self.remoteDataClient = remoteDataClient;
        self.dataStore = dataStore;
        self.inAppMessageManager = inAppMessageManager;
        self.channel = channel;
        self.frequencyLimitManager = frequencyLimitManager;
        self.prepareSchedulePipeline = [UARetriablePipeline pipeline];
        self.frequencyCheckers = [NSMutableDictionary dictionary];
        self.privacyManager = privacyManager;
        self.automationEngine.delegate = self;
        self.remoteDataClient.delegate = self;
        self.inAppMessageManager.executionDelegate = self;
        self.disableHelper = [[UAComponentDisableHelper alloc] initWithDataStore:dataStore
                                                                       className:@"UAInAppAutomation"];
        self.remoteDataInfoCache = [NSMutableDictionary dictionary];

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
    UARetriable *checkRequiresUpdate = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)
        [self.remoteDataClient scheduleRequiresRefresh:schedule completionHandler:^(BOOL requiresUpdate) {
            if (requiresUpdate) {
                [self.remoteDataClient waitFullRefresh:schedule completionHandler:^{
                    completionHandler(UAAutomationSchedulePrepareResultInvalidate);
                }];
                retriableHandler(UARetriableResultCancel, 0);
            } else {
                retriableHandler(UARetriableResultSuccess, 0);
            }
        }];
    }];

    UARetriable *checkValid = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)
        [self.remoteDataClient bestEffortRefresh:schedule completionHandler:^(BOOL isValid) {
            if (isValid) {
                retriableHandler(UARetriableResultSuccess, 0);
            } else {
                completionHandler(UAAutomationSchedulePrepareResultInvalidate);
                retriableHandler(UARetriableResultCancel, 0);
            }
        }];
    }];


    __block UAFrequencyChecker *checker;
    UARetriable *checkFrequencyLimits = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler retriableHandler) {
        [self.frequencyLimitManager getFrequencyChecker:schedule.frequencyConstraintIDs completionHandler:^(UAFrequencyChecker *c) {
            if (!c) {
                [self.remoteDataClient notifyOutdatedSchedule:schedule completionHandler:^{
                    completionHandler(UAAutomationSchedulePrepareResultInvalidate);
                }];
                retriableHandler(UARetriableResultCancel, 0);
                return;
            }
            
            checker = c;
            if (checker.isOverLimit) {
                // If we're over the limit, skip the rest of the prepare steps and cancel the pipeline
                completionHandler(UAAutomationSchedulePrepareResultSkip);
                retriableHandler(UARetriableResultCancel, 0);
            } else {
                retriableHandler(UARetriableResultSuccess, 0);
            }
        }];
    }];

    __block UAInAppAudience *audience;
    // Check audience conditions
    UARetriable *checkAudience = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {

        NSError *error;
        audience = [self.inAppCoreSwiftBridge audienceWithSelectorJSON:schedule.audienceJSON
                                               isNewUserEvaluationDate:schedule.isNewUserEvaluationDate
                                                             contactID:[self.remoteDataClient remoteDataInfoFromSchedule:schedule].contactID
                                                                 error:&error];
        if (!audience || error) {
            UA_LERR(@"Failed to process audience %@", error);
            completionHandler(UAAutomationSchedulePrepareResultSkip);
            retriableHandler(UARetriableResultCancel, 0);
        } else {
            [audience evaluateAudienceWithCompletionHandler:^(BOOL success, NSError *error) {
                if (error) {
                    retriableHandler(UARetriableResultRetry, 0);
                } else if (success) {
                    retriableHandler(UARetriableResultSuccess, 0);
                } else {
                    retriableHandler(UARetriableResultCancel, 0);
                    completionHandler([UAInAppAutomation prepareResultForMissedBehavior:schedule.audienceMissBehavior]);
                }
            }];
        }
    }];

    void (^prepareCompletionHandlerWrapper)(UAAutomationSchedulePrepareResult) = ^(UAAutomationSchedulePrepareResult result){
        UA_STRONGIFY(self)
        if (result == UAAutomationSchedulePrepareResultContinue) {
            if (checker) {
                self.frequencyCheckers[scheduleID] = checker;
            }

            UARemoteDataInfo *info = [self.remoteDataClient remoteDataInfoFromSchedule:schedule];
            if (info) {
                self.remoteDataInfoCache[scheduleID] = info;
            }
        }
        completionHandler(result);
    };

    // Evaluate experiements
    __block UAExperimentResult *experimentResult;
    UARetriable *evaluateExperiments = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)
        [self evaluateExperimentsForSchedule:schedule audience:audience completionHandler:^(UAExperimentResult *result, NSError *error) {
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
                                     audience:audience
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
        checkRequiresUpdate,
        checkValid,
        checkFrequencyLimits,
        checkAudience,
        evaluateExperiments,
        prepare
    ]];
}

- (void)prepareDeferredSchedule:(UASchedule *)schedule
                       audience:(UAInAppAudience *)audience
                 triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
               experimentResult:(UAExperimentResult *)experimentResult
               retriableHandler:(UARetriableCompletionHandler) retriableHandler
              completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {

    UA_LDEBUG(@"Resolving deferred for schedule: %@", schedule.identifier);

    UAScheduleDeferredData *deferred = (UAScheduleDeferredData *)schedule.data;


    NSString *channelID = self.channel.identifier;
    if (!channelID) {
        retriableHandler(UARetriableResultRetry, 0);
        return;
    }

    [self.inAppCoreSwiftBridge resolveDeferredWithUrl:deferred.URL
                                            channelID:channelID 
                                             audience:audience
                                          triggerType:triggerContext.trigger.typeName
                                          triggerEvent:triggerContext.event
                                          triggerGoal:triggerContext.trigger.goal.doubleValue
                                          completionHandler:^(UAInAppDeferredResult *result) {
        
        // Success
        if (result.isSuccess) {
            NSDictionary *responseBody = result.responseBody ?: [NSDictionary dictionary];

            BOOL audienceMatch = [responseBody numberForKey:kUADeferredScheduleAPIClientAudienceMatchKey defaultValue:@(NO)].boolValue;
            if (audienceMatch) {
                UA_LDEBUG(@"Deferred for schedule is a match: %@", schedule.identifier);

                UAInAppMessage *message;
                NSError *error;

                NSString *responseType = [responseBody stringForKey:kUADeferredScheduleAPIClientResponseTypeKey defaultValue:nil];
                if ([responseType isEqualToString:kUADeferredScheduleAPIClientInAppMessageType]) {
                    NSDictionary *messageJSON = [responseBody dictionaryForKey:kUADeferredScheduleAPIClientMessageKey defaultValue:nil];
                    message = [UAInAppMessage messageWithJSON:messageJSON defaultSource:UAInAppMessageSourceRemoteData error:&error];
                }

                if (error || !message) {
                    UA_LDEBUG(@"Unable to create in-app message from response body: %@", responseBody);
                    completionHandler(UAAutomationSchedulePrepareResultPenalize);
                    retriableHandler(UARetriableResultCancel, 0);
                } else {
                    [self.inAppMessageManager prepareMessage:message
                                                  scheduleID:schedule.identifier
                                                   campaigns:schedule.campaigns
                                            reportingContext:schedule.reportingContext
                                            experimentResult:experimentResult
                                           completionHandler:completionHandler];
                    retriableHandler(UARetriableResultSuccess, 0);
                }
            } else {
                UA_LDEBUG(@"Audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", schedule.identifier, (long)schedule.audience.missBehavior);
                completionHandler([UAInAppAutomation prepareResultForMissedBehavior:schedule.audienceMissBehavior]);
                retriableHandler(UARetriableResultCancel, 0);
            }

            return;
        }

        // Timed out
        if (result.timedOut) {
            UA_LDEBUG(@"Deferred timed out for scheduleID: %@", schedule.identifier);

            if (deferred.retriableOnTimeout) {
                retriableHandler(UARetriableResultRetry, 0);
            } else {
                retriableHandler(UARetriableResultSuccess, 0);
                completionHandler(UAAutomationSchedulePrepareResultPenalize);
            }
            return;
        }

        // Remote-data is out of date
        if (result.isOutOfDate) {
            UA_LDEBUG(@"Deferred is out of date for scheduleID: %@", schedule.identifier);
            [self.remoteDataClient notifyOutdatedSchedule:schedule completionHandler:^{
                                       completionHandler(UAAutomationSchedulePrepareResultInvalidate);
                                   }];
            retriableHandler(UARetriableResultCancel, 0);
            return;
        }

        UA_LDEBUG(@"Deferred failed, retrying: %@", schedule.identifier);

        NSTimeInterval backoff = result.backOff;
        if (backoff == 0) {
            retriableHandler(UARetriableResultRetryWithBackoffReset, 0);
        } else if (backoff > 0) {
            retriableHandler(UARetriableResultRetryAfter, backoff);
        } else {
            retriableHandler(UARetriableResultRetry, 0);
        }
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
        UA_LTRACE(@"InAppAutomation currently paused. Schedule: %@ not ready.", schedule.identifier);
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
    
    NSString *contactId = self.remoteDataInfoCache[schedule.identifier].contactID.copy;

    [self.frequencyCheckers removeObjectForKey:schedule.identifier];
    [self.remoteDataInfoCache removeObjectForKey:schedule.identifier];

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
            [self reportMeteredUsage:schedule contactId:contactId];
            break;
        }

        default: {
            UA_LERR(@"Unexpected schedule type: %ld", schedule.type);
            return completionHandler();
        }
    }
}

- (void)reportMeteredUsage:(nonnull UASchedule *)schedule contactId:(NSString *)contactId {
    if (schedule.productId.length == 0) {
        return;
    }
    
    [self.inAppCoreSwiftBridge addImpressionWithEntityID:schedule.identifier
                                         product:schedule.productId
                                       contactID:contactId
                                reportingContext:schedule.reportingContext];
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

    UARemoteDataInfo *info = [self.remoteDataClient remoteDataInfoFromSchedule:schedule];
    if (info && ![info isEqual:self.remoteDataInfoCache[schedule.identifier]]) {
        if (schedule.type == UAScheduleTypeInAppMessage) {
            [self.inAppMessageManager scheduleExecutionAborted:schedule.identifier];
        }
        completionHandler(UAAutomationScheduleReadyResultInvalidate);
        return;
    }

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

- (void)updateConstraints:(NSArray<UAFrequencyConstraint *> *)constraints completionHandler:(nonnull void (^)(BOOL))completionHandler {
     [self.frequencyLimitManager updateConstraints:constraints completionHandler:completionHandler];
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
                              audience:(UAInAppAudience *)audience
                     completionHandler:(void (^)(UAExperimentResult *, NSError *))completionHandler {

    // Skip actions for now
    if (schedule.type == UAScheduleTypeActions) {
        completionHandler(nil, nil);
        return;
    }

    if (schedule.bypassHoldoutGroups) {
        completionHandler(nil, nil);
    } else {
        UAExperimentMessageInfo *info = [[UAExperimentMessageInfo alloc] initWithMessageType:schedule.messageType ?: UADefaultScheduleMessageType
                                                                               campaignsJSON:schedule.campaigns];
        [audience evaluateExperimentsWithInfo:info completionHandler:completionHandler];
    }
}

- (void)checkAudience:(nonnull UAScheduleAudience *)audience 
    completionHandler:(nonnull void (^)(BOOL, NSError *))completionHandler {

    NSError *error;
    UAInAppAudience *inAppAudience = [self.inAppCoreSwiftBridge audienceWithSelectorJSON:audience.toJSON
                                                                 isNewUserEvaluationDate:[NSDate date]
                                                                               contactID:nil
                                                                                   error:&error];

    if (!inAppAudience || error) {
        UA_LERR(@"Failed to process audience %@", error);
        completionHandler(error, false);
    } else {
        [inAppAudience evaluateAudienceWithCompletionHandler:completionHandler];
    }
}

@end
