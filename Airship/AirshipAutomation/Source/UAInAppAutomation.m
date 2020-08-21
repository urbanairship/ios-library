/* Copyright Airship and Contributors */

#import "UAInAppAutomation+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessagingRemoteConfig+Internal.h"
#import "UAInAppAudienceManager+Internal.h"
#import "UATagSelector+Internal.h"
#import "UARetriable+Internal.h"
#import "UARetriablePipeline+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAScheduleAudience.h"
#import "UAScheduleAudienceChecks+Internal.h"
#import "UAInAppMessageSchedule.h"
#import "UADeferredScheduleAPIClient+Internal.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const MaxSchedules = 1000;

NSString *const UAInAppMessageManagerEnabledKey = @"UAInAppMessageManagerEnabled";
NSString *const UAInAppMessageManagerPausedKey = @"UAInAppMessageManagerPaused";

@interface UAInAppAutomation () <UAAutomationEngineDelegate, UAInAppAudienceManagerDelegate, UAInAppRemoteDataClientDelegate, UAInAppMessagingExecutionDelegate>

@property(nonatomic, strong) UAAutomationEngine *automationEngine;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAInAppAudienceManager *audienceManager;
@property(nonatomic, strong) UAInAppRemoteDataClient *remoteDataClient;
@property(nonatomic, strong) UARetriablePipeline *prepareSchedulePipeline;
@property(nonatomic, strong) UAInAppMessageManager *inAppMessageManager;
@property(nonatomic, strong) UADeferredScheduleAPIClient *deferredScheduleAPIClient;
@property(nonatomic, strong) UAChannel *channel;
@end

@implementation UAInAppAutomation

+ (instancetype)automationWithEngine:(UAAutomationEngine *)automationEngine
                     audienceManager:(UAInAppAudienceManager *)audienceManager
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                 inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                             channel:(UAChannel *)channel
           deferredScheduleAPIClient:(UADeferredScheduleAPIClient *)deferredScheduleAPIClient {

    return [[self alloc] initWithAutomationEngine:automationEngine
                                  audienceManager:audienceManager
                                 remoteDataClient:remoteDataClient
                                        dataStore:dataStore
                              inAppMessageManager:inAppMessageManager
                                          channel:channel
                        deferredScheduleAPIClient:deferredScheduleAPIClient];
}

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                     audienceManager:(UAInAppAudienceManager *)audienceManager
                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics {


    UAAutomationStore *store = [UAAutomationStore automationStoreWithConfig:config
                                                              scheduleLimit:MaxSchedules];
    UAAutomationEngine *automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:store];

    UAInAppRemoteDataClient *dataClient = [UAInAppRemoteDataClient clientWithRemoteDataProvider:remoteDataProvider
                                                                                      dataStore:dataStore
                                                                                        channel:channel];

    UAInAppMessageManager *inAppMessageManager = [UAInAppMessageManager managerWithDataStore:dataStore
                                                                                   analytics:analytics];

    UAAuthTokenManager *authManager = [UAAuthTokenManager authTokenManagerWithRuntimeConfig:config
                                                                                    channel:channel];

    UADeferredScheduleAPIClient *deferredScheduleAPIClient = [UADeferredScheduleAPIClient clientWithConfig:config
                                                                                            authManager:authManager];
    return [[UAInAppAutomation alloc] initWithAutomationEngine:automationEngine
                                               audienceManager:audienceManager
                                              remoteDataClient:dataClient
                                                     dataStore:dataStore
                                           inAppMessageManager:inAppMessageManager
                                                       channel:channel
                                     deferredScheduleAPIClient:deferredScheduleAPIClient];
}

- (instancetype)initWithAutomationEngine:(UAAutomationEngine *)automationEngine
                         audienceManager:(UAInAppAudienceManager *)audienceManager
                        remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                               dataStore:(UAPreferenceDataStore *)dataStore
                     inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                                 channel:(UAChannel *)channel
               deferredScheduleAPIClient:(UADeferredScheduleAPIClient *)deferredScheduleAPIClient {

    self = [super initWithDataStore:dataStore];

    if (self) {
        self.automationEngine = automationEngine;
        self.audienceManager = audienceManager;
        self.remoteDataClient = remoteDataClient;
        self.dataStore = dataStore;
        self.inAppMessageManager = inAppMessageManager;
        self.channel = channel;
        self.deferredScheduleAPIClient = deferredScheduleAPIClient;
        self.prepareSchedulePipeline = [UARetriablePipeline pipeline];

        self.automationEngine.delegate = self;
        self.audienceManager.delegate = self;
        self.remoteDataClient.delegate = self;
        self.inAppMessageManager.executionDelegate = self;

        [self.remoteDataClient subscribe];
    }

    return self;
}

-(void)airshipReady:(UAirship *)airship {
    [self.automationEngine start];
    [self updateEnginePauseState];
}

- (void)getMessageScheduleWithID:(NSString *)identifier
               completionHandler:(void (^)(UAInAppMessageSchedule *))completionHandler {
    [self.automationEngine getScheduleWithID:identifier
                                        type:UAScheduleTypeInAppMessage
                           completionHandler:^(UASchedule *schedule) {
        completionHandler((UAInAppMessageSchedule *)schedule);
    }];
}

- (void)getMessageSchedulesWithGroup:(NSString *)group
                   completionHandler:(void (^)(NSArray<UAInAppMessageSchedule *> *))completionHandler {
    [self.automationEngine getSchedulesWithGroup:group
                                            type:UAScheduleTypeInAppMessage
                               completionHandler:completionHandler];
}

- (void)getMessageSchedules:(void (^)(NSArray<UAInAppMessageSchedule *> *))completionHandler {
    [self.automationEngine getSchedulesWithType:UAScheduleTypeInAppMessage completionHandler:completionHandler];
}

- (void)getActionScheduleWithID:(NSString *)identifier
              completionHandler:(void (^)(UAActionSchedule *))completionHandler {
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
    [self.automationEngine getSchedulesWithGroup:group
                                            type:UAScheduleTypeActions
                               completionHandler:completionHandler];
}

- (void)getActionSchedules:(void (^)(NSArray<UAActionSchedule *> *))completionHandler {
    [self.automationEngine getSchedulesWithType:UAScheduleTypeActions completionHandler:completionHandler];
}

- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self.automationEngine getSchedules:completionHandler];
}

- (void)schedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    [self.automationEngine schedule:schedule completionHandler:completionHandler];
}

- (void)scheduleMultiple:(NSArray<UASchedule *> *)schedules completionHandler:(void (^)(BOOL))completionHandler {
    [self.automationEngine scheduleMultiple:schedules completionHandler:completionHandler];
}

- (void)cancelScheduleWithID:(NSString *)scheduleID
           completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self.automationEngine cancelScheduleWithID:scheduleID completionHandler:completionHandler];
}

- (void)cancelSchedulesWithType:(UAScheduleType)scheduleType
              completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self.automationEngine cancelSchedulesWithType:scheduleType completionHandler:completionHandler];
}

- (void)cancelSchedulesWithGroup:(NSString *)group
               completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self.automationEngine cancelSchedulesWithGroup:group completionHandler:completionHandler];
}

- (void)cancelMessageSchedulesWithGroup:(NSString *)group
                      completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self.automationEngine cancelSchedulesWithGroup:group
                                               type:UAScheduleTypeInAppMessage
                                  completionHandler:completionHandler];
}

- (void)cancelActionSchedulesWithGroup:(NSString *)group
                     completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self.automationEngine cancelSchedulesWithGroup:group
                                               type:UAScheduleTypeActions
                                  completionHandler:completionHandler];
}


- (void)editScheduleWithID:(NSString *)scheduleID
                     edits:(UAScheduleEdits *)edits
         completionHandler:(nullable void (^)(BOOL))completionHandler {
    [self.automationEngine editScheduleWithID:scheduleID edits:edits completionHandler:completionHandler];
}

- (void)prepareSchedule:(UASchedule *)schedule
         triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
      completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {

    UA_LDEBUG(@"Trigger Context trigger: %@ event: %@", triggerContext.trigger, triggerContext.event);
    UA_LDEBUG(@"Preparing schedule: %@", schedule.identifier);

    if ([self isScheduleInvalid:schedule]) {
        [self.remoteDataClient notifyOnUpdate:^{
            completionHandler(UAAutomationSchedulePrepareResultInvalidate);
        }];
        return;
    }

    NSString *scheduleID = schedule.identifier;

    // Check audience conditions
    UARetriable *checkAudience = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UAScheduleAudience *audience = schedule.audience;
        [self checkAudience:audience completionHandler:^(BOOL success, NSError *error) {
            if (error) {
                retriableHandler(UARetriableResultRetry);
            } else if (success) {
                retriableHandler(UARetriableResultSuccess);
            } else {
                UA_LDEBUG(@"Message audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", scheduleID, (long)audience.missBehavior);
                completionHandler([UAInAppAutomation prepareResultForMissedAudience:schedule.audience]);
                retriableHandler(UARetriableResultCancel);
            }
        }];
    }];

    // Prepare
    UA_WEAKIFY(self)
    UARetriable *prepare = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)

        switch (schedule.type) {
            case UAScheduleTypeActions:
                completionHandler(UAAutomationSchedulePrepareResultContinue);
                retriableHandler(UARetriableResultSuccess);
                break;

            case UAScheduleTypeInAppMessage:
                [self.inAppMessageManager prepareMessage:(UAInAppMessage *) schedule.data
                                              scheduleID:schedule.identifier
                                       completionHandler:completionHandler];
                retriableHandler(UARetriableResultSuccess);
                break;

            case UAScheduleTypeDeferred:
                [self prepareDeferredSchedule:schedule
                               triggerContext:triggerContext
                             retriableHandler:retriableHandler
                            completionHandler:completionHandler];
                break;


            default:
                UA_LERR(@"Unexpected schedule type: %ld", schedule.type);
                retriableHandler(UARetriableResultSuccess);
        }
    }];

    [self.prepareSchedulePipeline addChainedRetriables:@[checkAudience, prepare]];
}

- (void)prepareDeferredSchedule:(UASchedule *)schedule
                 triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
               retriableHandler:(UARetriableCompletionHandler) retriableHandler
              completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {

    UAScheduleDeferredData *deferred =  (UAScheduleDeferredData *)schedule.data;
    NSString *channelID = self.channel.identifier;
    if (!channelID) {
        retriableHandler(UARetriableResultRetry);
        return;
    }

    [self.deferredScheduleAPIClient resolveURL:deferred.URL
                                     channelID:channelID
                                triggerContext:triggerContext
                             completionHandler:^(UADeferredScheduleResult *result, NSError *error) {
        if (error) {
            switch (error.code) {
                case UADeferredScheduleAPIClientErrorTimedOut:
                    if (deferred.retriableOnTimeout) {
                        retriableHandler(UARetriableResultRetry);
                    } else {
                        retriableHandler(UARetriableResultSuccess);
                        completionHandler(UAAutomationSchedulePrepareResultPenalize);
                    }
                    break;

                case UADeferredScheduleAPIClientErrorMissingAuthToken:
                case UADeferredScheduleAPIClientErrorUnsuccessfulStatus:
                default:
                    retriableHandler(UARetriableResultRetry);
                    break;
            }
        } else {
            if (!result.isAudienceMatch) {
                UA_LDEBUG(@"Audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", schedule.identifier, (long)schedule.audience.missBehavior);
                completionHandler([UAInAppAutomation prepareResultForMissedAudience:schedule.audience]);
                retriableHandler(UARetriableResultCancel);
            } else if (result.message) {
                [self.inAppMessageManager prepareMessage:result.message
                                              scheduleID:schedule.identifier
                                       completionHandler:completionHandler];
                retriableHandler(UARetriableResultSuccess);
            } else {
                completionHandler(UAAutomationSchedulePrepareResultPenalize);
                retriableHandler(UARetriableResultSuccess);
            }
        }
    }];
}

+ (UAAutomationSchedulePrepareResult)prepareResultForMissedAudience:(UAScheduleAudience *)audience {
    if (!audience) {
        return UAAutomationSchedulePrepareResultPenalize;
    }

    switch(audience.missBehavior) {
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

    if ([self isScheduleInvalid:schedule]) {
        if (schedule.type == UAScheduleTypeInAppMessage) {
            [self.inAppMessageManager scheduleExecutionAborted:schedule.identifier];
        }
        return UAAutomationScheduleReadyResultInvalidate;
    }

    switch (schedule.type) {
        case UAScheduleTypeActions:
            return UAAutomationScheduleReadyResultContinue;

        case UAScheduleTypeInAppMessage:
            return [self.inAppMessageManager isReadyToDisplay:schedule.identifier];

        default:
            UA_LERR(@"Unexpected schedule type: %ld", schedule.type);
            return UAAutomationScheduleReadyResultContinue;
    }
}

- (void)executeSchedule:(nonnull UASchedule *)schedule completionHandler:(void (^)(void))completionHandler {
    UA_LTRACE(@"Executing schedule: %@", schedule.identifier);

    switch (schedule.type) {
        case UAScheduleTypeActions: {
            // Run the actions
            [UAActionRunner runActionsWithActionValues:schedule.data
                                             situation:UASituationAutomation
                                              metadata:nil
                                     completionHandler:^(UAActionResult *result) {
                completionHandler();
            }];
            break;
        }

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

/**
 * Checks to see if a schedule from remote-data is still valid.
 *
 * @param schedule The in-app schedule.
 * @return `YES` if the schedule is valid, otherwise `NO`.
 */
-(BOOL)isScheduleInvalid:(UASchedule *)schedule {
    return [self.remoteDataClient isRemoteSchedule:schedule] &&
    ![self.remoteDataClient isScheduleUpToDate:schedule];
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

- (void)onComponentEnableChange {
    [self updateEnginePauseState];
}

- (void)applyRemoteConfig:(nullable id)config {
    UAInAppMessagingRemoteConfig *inAppConfig = nil;
    if (config) {
        inAppConfig = [UAInAppMessagingRemoteConfig configWithJSON:config];
    }
    inAppConfig = inAppConfig ?: [UAInAppMessagingRemoteConfig defaultConfig];

    self.audienceManager.enabled = inAppConfig.tagGroupsConfig.enabled;
    self.audienceManager.cacheMaxAgeTime = inAppConfig.tagGroupsConfig.cacheMaxAgeTime;
    self.audienceManager.cacheStaleReadTime = inAppConfig.tagGroupsConfig.cacheStaleReadTime;
    self.audienceManager.preferLocalTagDataTime = inAppConfig.tagGroupsConfig.cachePreferLocalUntil;
}

- (void)setPaused:(BOOL)paused {
    // If we're unpausing, alert the automation engine
    if (self.isPaused == YES && self.isPaused != paused) {
        [self.automationEngine scheduleConditionsChanged];
    }

    [self.dataStore setBool:paused forKey:UAInAppMessageManagerPausedKey];
}

- (BOOL)isPaused{
    return [self.dataStore boolForKey:UAInAppMessageManagerPausedKey defaultValue:NO];
}

- (void)setEnabled:(BOOL)enabled {
    [self.dataStore setBool:enabled forKey:UAInAppMessageManagerEnabledKey];
    [self updateEnginePauseState];
}

- (BOOL)isEnabled {
    return [self.dataStore boolForKey:UAInAppMessageManagerEnabledKey defaultValue:YES];
}

- (void)updateEnginePauseState {
    if (self.componentEnabled && self.isEnabled) {
        [self.automationEngine resume];
    } else {
        [self.automationEngine pause];
    }
}

- (void)dealloc {
    [self.automationEngine stop];
    self.automationEngine.delegate = nil;
}

- (void)gatherTagGroupsWithCompletionHandler:(void(^)(UATagGroups *tagGroups))completionHandler {
    __block UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{}];

    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *schedules) {
        for (UASchedule *schedule in schedules) {
            if ([schedule.audience.tagSelector containsTagGroups]) {
                tagGroups = [tagGroups merge:schedule.audience.tagSelector.tagGroups];
            }
        }

        completionHandler(tagGroups);
    }];
}

- (void)checkAudience:(UAScheduleAudience *)audience completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    void (^performAudienceCheck)(UATagGroups *) = ^(UATagGroups *tagGroups) {
        if ([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience tagGroups:tagGroups]) {
            completionHandler(YES, nil);
        } else {
            completionHandler(NO, nil);
        }
    };

    UATagGroups *requestedTagGroups = audience.tagSelector.tagGroups;

    if (requestedTagGroups.tags.count) {
        [self.audienceManager getTagGroups:requestedTagGroups completionHandler:^(UATagGroups * _Nullable tagGroups, NSError * _Nonnull error) {
            if (error) {
                completionHandler(NO, error);
            } else {
                performAudienceCheck(tagGroups);
            }
        }];
    } else {
        performAudienceCheck(nil);
    }
}

- (void)executionReadinessChanged {
    [self.automationEngine scheduleConditionsChanged];
}

- (void)cancelScheduleWithID:(nonnull NSString *)scheduleID {
    [self.automationEngine cancelScheduleWithID:scheduleID completionHandler:nil];
}

@end

NS_ASSUME_NONNULL_END
