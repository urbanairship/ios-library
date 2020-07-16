/* Copyright Airship and Contributors */

#import "UAInAppAutomation+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessagingRemoteConfig+Internal.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAActiveTimer+Internal.h"
#import "UARetriable+Internal.h"
#import "UARetriablePipeline+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageAudience.h"
#import "UAInAppMessageAudienceChecks+Internal.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const MaxSchedules = 200;

NSString *const UAInAppAutomationStoreFileFormat = @"In-app-automation-%@.sqlite";
NSString *const UAInAppMessageManagerEnabledKey = @"UAInAppMessageManagerEnabled";
NSString *const UAInAppMessageManagerPausedKey = @"UAInAppMessageManagerPaused";

@interface UAInAppAutomation () <UAAutomationEngineDelegate, UATagGroupsLookupManagerDelegate, UAInAppRemoteDataClientDelegate, UAInAppMessagingExecutionDelegate>

@property(nonatomic, strong) UAAutomationEngine *automationEngine;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UATagGroupsLookupManager *tagGroupsLookupManager;
@property(nonatomic, strong) UAInAppRemoteDataClient *remoteDataClient;
@property(nonatomic, strong) UARetriablePipeline *prepareSchedulePipeline;
@property(nonatomic, strong) UAInAppMessageManager *inAppMessageManager;

@end

@implementation UAInAppAutomation

+ (instancetype)automationWithEngine:(UAAutomationEngine *)automationEngine
              tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                inAppMesssageManager:(UAInAppMessageManager *)inAppMessageManager {

    return [[self alloc] initWithAutomationEngine:automationEngine
                           tagGroupsLookupManager:tagGroupsLookupManager
                                 remoteDataClient:remoteDataClient
                                        dataStore:dataStore
                              inAppMessageManager:inAppMessageManager];
}

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                    tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory
                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics {

    NSString *storeName = [NSString stringWithFormat:UAInAppAutomationStoreFileFormat, config.appKey];

    UAAutomationStore *store = [UAAutomationStore automationStoreWithStoreName:storeName scheduleLimit:MaxSchedules];
    UAAutomationEngine *automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:store];

    UATagGroupsLookupManager *lookupManager = [UATagGroupsLookupManager lookupManagerWithConfig:config
                                                                                      dataStore:dataStore
                                                                               tagGroupsHistory:tagGroupsHistory];

    UAInAppRemoteDataClient *dataClient = [UAInAppRemoteDataClient clientWithRemoteDataProvider:remoteDataProvider
                                                                                      dataStore:dataStore
                                                                                        channel:channel];

    UAInAppMessageManager *inAppMessageManager = [UAInAppMessageManager managerWithDataStore:dataStore
                                                                                   analytics:analytics];

    return [[UAInAppAutomation alloc] initWithAutomationEngine:automationEngine
                                        tagGroupsLookupManager:lookupManager
                                              remoteDataClient:dataClient
                                                     dataStore:dataStore
                                           inAppMessageManager:inAppMessageManager];
}

- (instancetype)initWithAutomationEngine:(UAAutomationEngine *)automationEngine
                  tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                        remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                               dataStore:(UAPreferenceDataStore *)dataStore
                     inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager {

    self = [super initWithDataStore:dataStore];

    if (self) {
        self.automationEngine = automationEngine;
        self.tagGroupsLookupManager = tagGroupsLookupManager;
        self.remoteDataClient = remoteDataClient;
        self.dataStore = dataStore;
        self.inAppMessageManager = inAppMessageManager;
        self.prepareSchedulePipeline = [UARetriablePipeline pipeline];

        self.automationEngine.delegate = self;
        self.tagGroupsLookupManager.delegate = self;
        self.remoteDataClient.delegate = self;
        self.inAppMessageManager.executionDelegate = self;

        [self.automationEngine start];
        [self updateEnginePauseState];
        [self.remoteDataClient subscribe];
    }

    return self;
}

- (void)getScheduleWithID:(NSString *)identifier completionHandler:(void (^)(UASchedule * _Nullable))completionHandler {
    [self.automationEngine getScheduleWithID:identifier completionHandler:completionHandler];
}

- (void)getSchedulesWithMessageID:(NSString *)messageID completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self.automationEngine getSchedulesWithGroup:messageID completionHandler:completionHandler];
}

- (void)getAllSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self.automationEngine getAllSchedules:completionHandler];
}

- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler {
    [self scheduleMessageWithScheduleInfo:scheduleInfo metadata:nil completionHandler:completionHandler];
}

- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                               metadata:(nullable NSDictionary *)metadata
                      completionHandler:(void (^)(UASchedule *))completionHandler {
    [self.automationEngine schedule:scheduleInfo
                           metadata:metadata
                  completionHandler:completionHandler];
}

- (void)scheduleMessagesWithScheduleInfo:(NSArray<UAInAppMessageScheduleInfo *> *)scheduleInfos
                                metadata:(nullable NSDictionary *)metadata
                       completionHandler:(void (^)(NSArray <UASchedule *> *))completionHandler {
    [self.automationEngine scheduleMultiple:scheduleInfos
                                   metadata:metadata
                          completionHandler:completionHandler];
}

- (void)cancelMessagesWithID:(NSString *)identifier completionHandler:(nullable void (^)(NSArray <UASchedule *> *))completionHandler {
    [self.automationEngine cancelSchedulesWithGroup:identifier completionHandler:completionHandler];
}

- (void)cancelMessagesWithID:(NSString *)identifier {
    [self cancelMessagesWithID:identifier completionHandler:nil];
}

- (void)cancelScheduleWithID:(NSString *)scheduleID completionHandler:(nullable void (^)(UASchedule * _Nullable))completionHandler {
    [self.automationEngine cancelScheduleWithID:scheduleID completionHandler:completionHandler];
}

- (void)cancelScheduleWithID:(NSString *)scheduleID {
    [self cancelScheduleWithID:scheduleID completionHandler:nil];
}

- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAInAppMessageScheduleEdits *)edits
         completionHandler:(void (^)(UASchedule * _Nullable))completionHandler {

    [self.automationEngine editScheduleWithID:identifier edits:edits completionHandler:completionHandler];
}

- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder {
    return [[UAInAppMessageScheduleInfo alloc] initWithBuilder:builder];
}

- (void)prepareSchedule:(UASchedule *)schedule
      completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {

    UA_LDEBUG(@"Preparing schedule: %@", schedule.identifier);

    if ([self isScheduleInvalid:schedule]) {
        [self.remoteDataClient notifyOnUpdate:^{
            completionHandler(UAAutomationSchedulePrepareResultInvalidate);
        }];
        return;
    }

    UAInAppMessage *message = ((UAInAppMessageScheduleInfo *)schedule.info).message;
    NSString *scheduleID = schedule.identifier;

    // Check audience conditions
    UARetriable *checkAudience = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        [self checkAudience:message.audience completionHandler:^(BOOL success, NSError *error) {
            if (error) {
                retriableHandler(UARetriableResultRetry);
            } else if (success) {
                retriableHandler(UARetriableResultSuccess);
            } else {
                UA_LDEBUG(@"Message audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", scheduleID, (long)message.audience.missBehavior);
                switch(message.audience.missBehavior) {
                    case UAInAppMessageAudienceMissBehaviorCancel:
                        completionHandler(UAAutomationSchedulePrepareResultCancel);
                        break;
                    case UAInAppMessageAudienceMissBehaviorSkip:
                        completionHandler(UAAutomationSchedulePrepareResultSkip);
                        break;
                    case UAInAppMessageAudienceMissBehaviorPenalize:
                        completionHandler(UAAutomationSchedulePrepareResultPenalize);
                        break;
                }
                retriableHandler(UARetriableResultCancel);
            }
        }];
    }];

    // Prepare
    UA_WEAKIFY(self)
    UARetriable *prepare = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull retriableHandler) {
        UA_STRONGIFY(self)
        [self.inAppMessageManager prepareMessage:((UAInAppMessageScheduleInfo *)schedule.info).message
                                      scheduleID:schedule.identifier
                               completionHandler:completionHandler];
        retriableHandler(UARetriableResultSuccess);
    }];

    [self.prepareSchedulePipeline addChainedRetriables:@[checkAudience, prepare]];
}

- (UAAutomationScheduleReadyResult)isScheduleReadyToExecute:(UASchedule *)schedule {
    UA_LTRACE(@"Checking if schedule %@ is ready to execute.", schedule.identifier);

    if ([self isScheduleInvalid:schedule]) {
        UA_LTRACE(@"Metadata is out of date, invalidating schedule with id: %@ until refresh can occur.", schedule.identifier);
        [self.inAppMessageManager scheduleExecutionAborted:schedule.identifier];
        return UAAutomationScheduleReadyResultInvalidate;
    }

    if (self.isPaused) {
        UA_LTRACE(@"InAppAutoamtion currently paused. Schedule: %@ not ready.", schedule.identifier);
        return UAAutomationScheduleReadyResultNotReady;
    }

    return [self.inAppMessageManager isReadyToDisplay:schedule.identifier];
}

- (void)executeSchedule:(nonnull UASchedule *)schedule completionHandler:(void (^)(void))completionHandler {
    UA_LTRACE(@"Executing schedule: %@", schedule.identifier);
    [self.inAppMessageManager displayMessageWithScheduleID:schedule.identifier completionHandler:completionHandler];
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
    [self.inAppMessageManager messageExpired:((UAInAppMessageScheduleInfo *)schedule.info).message
                                  scheduleID:schedule.identifier
                              expirationDate:schedule.info.end];

}

- (void)onScheduleCancelled:(UASchedule *)schedule {
    [self.inAppMessageManager messageCancelled:((UAInAppMessageScheduleInfo *)schedule.info).message
                                    scheduleID:schedule.identifier];
}

- (void)onScheduleLimitReached:(UASchedule *)schedule {
    [self.inAppMessageManager messageLimitReached:((UAInAppMessageScheduleInfo *)schedule.info).message
                                       scheduleID:schedule.identifier];
}

- (void)onNewSchedule:(nonnull UASchedule *)schedule {
    [self.inAppMessageManager messageScheduled:((UAInAppMessageScheduleInfo *)schedule.info).message
                                    scheduleID:schedule.identifier];
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

    self.tagGroupsLookupManager.enabled = inAppConfig.tagGroupsConfig.enabled;
    self.tagGroupsLookupManager.cacheMaxAgeTime = inAppConfig.tagGroupsConfig.cacheMaxAgeTime;
    self.tagGroupsLookupManager.cacheStaleReadTime = inAppConfig.tagGroupsConfig.cacheStaleReadTime;
    self.tagGroupsLookupManager.preferLocalTagDataTime = inAppConfig.tagGroupsConfig.cachePreferLocalUntil;
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
            UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
            if ([info.message.audience.tagSelector containsTagGroups]) {
                tagGroups = [tagGroups merge:info.message.audience.tagSelector.tagGroups];
            }
        }

        completionHandler(tagGroups);
    }];
}

- (void)checkAudience:(UAInAppMessageAudience *)audience completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    void (^performAudienceCheck)(UATagGroups *) = ^(UATagGroups *tagGroups) {
        if ([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience tagGroups:tagGroups]) {
            completionHandler(YES, nil);
        } else {
            completionHandler(NO, nil);
        }
    };

    UATagGroups *requestedTagGroups = audience.tagSelector.tagGroups;

    if (requestedTagGroups.tags.count) {
        [self.tagGroupsLookupManager getTagGroups:requestedTagGroups completionHandler:^(UATagGroups * _Nullable tagGroups, NSError * _Nonnull error) {
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

@end

NS_ASSUME_NONNULL_END




