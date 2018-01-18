/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageFullScreenAdapter.h"
#import "UAInAppMessageModalAdapter.h"
#import "UAGlobal.h"
#import "UAConfig.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAAsyncOperation+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAirship.h"
#import "UAActiveTimer+Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSTimeInterval const DefaultMessageDisplayInterval = 30;
NSTimeInterval const MaxSchedules = 200;
NSTimeInterval const MessagePrepareRetyDelay = 200;

NSString *const UAInAppAutomationStoreFileFormat = @"In-app-automation-%@.sqlite";
NSString *const UAInAppMessageManagerEnabledKey = @"UAInAppMessageManagerEnabled";


@interface UAInAppMessageScheduleData : NSObject
@property(nonatomic, strong, nonnull) id<UAInAppMessageAdapterProtocol> adapter;
@property(nonatomic, copy, nonnull) NSString *scheduleID;
@property(assign) BOOL isPrepareFinished;
+ (instancetype)dataWithAdapter:(id<UAInAppMessageAdapterProtocol>)adapter scheduleID:(NSString *)scheduleID;
@end

@implementation UAInAppMessageScheduleData

- (instancetype)initWithAdapter:(id<UAInAppMessageAdapterProtocol>)adapter scheduleID:(NSString *)scheduleID {
    self = [super init];
    if (self) {
        self.adapter = adapter;
        self.scheduleID = scheduleID;
    }
    return self;
}

+ (instancetype)dataWithAdapter:(id<UAInAppMessageAdapterProtocol>)adapter scheduleID:(NSString *)scheduleID {
    return [[self alloc] initWithAdapter:adapter scheduleID:scheduleID];
}

@end


@interface UAInAppMessageManager ()  <UAAutomationEngineDelegate>

@property(nonatomic, assign) BOOL isDisplayLocked;
@property(nonatomic, strong, nullable) NSMutableDictionary *adapterFactories;
@property(nonatomic, strong, nullable) UAAutomationEngine *automationEngine;
@property(nonatomic, strong) UAInAppRemoteDataClient *remoteDataClient;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong, nonnull) NSOperationQueue *queue;
@property(nonatomic, strong, nonnull) NSMutableDictionary *scheduleData;
@end

@implementation UAInAppMessageManager

+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine
                          remoteDataManager:(UARemoteDataManager *)remoteDataManager
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                       push:(UAPush *)push {
    return [[UAInAppMessageManager alloc] initWithAutomationEngine:automationEngine remoteDataManager:remoteDataManager dataStore:dataStore push:push];
}

+ (instancetype)managerWithConfig:(UAConfig *)config
                remoteDataManager:(UARemoteDataManager *)remoteDataManager
                        dataStore:(UAPreferenceDataStore *)dataStore
                             push:(UAPush *)push {

    NSString *storeName = [NSString stringWithFormat:UAInAppAutomationStoreFileFormat, config.appKey];
    UAAutomationEngine *automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:[UAAutomationStore automationStoreWithStoreName:storeName]
                                                                                     scheduleLimit:MaxSchedules];

    return [[UAInAppMessageManager alloc] initWithAutomationEngine:automationEngine remoteDataManager:remoteDataManager dataStore:dataStore push:push];
}

- (instancetype)initWithAutomationEngine:(UAAutomationEngine *)automationEngine
                       remoteDataManager:(UARemoteDataManager *)remoteDataManager
                               dataStore:(UAPreferenceDataStore *)dataStore
                                    push:(UAPush *)push {
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
        self.scheduleData = [NSMutableDictionary dictionary];
        self.adapterFactories = [NSMutableDictionary dictionary];
        self.dataStore = dataStore;
        self.automationEngine = automationEngine;
        self.automationEngine.delegate = self;
        self.displayInterval = DefaultMessageDisplayInterval;
        self.remoteDataClient = [UAInAppRemoteDataClient clientWithScheduler:self remoteDataManager:remoteDataManager dataStore:dataStore push:push];
        [self setDefaultAdapterFactories];

        [self.automationEngine start];
        [self updateEnginePauseState];
    }

    return self;
}

// Sets the default adapter factories
- (void)setDefaultAdapterFactories {
    // Banner
    [self setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        return [UAInAppMessageBannerAdapter adapterForMessage:message];
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    // Full Screen
    [self setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        return [UAInAppMessageFullScreenAdapter adapterForMessage:message];
    } forDisplayType:UAInAppMessageDisplayTypeFullScreen];

    // Modal
    [self setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        return [UAInAppMessageModalAdapter adapterForMessage:message];
    } forDisplayType:UAInAppMessageDisplayTypeModal];
}

- (void)getScheduleWithID:(NSString *)identifier completionHandler:(void (^)(UASchedule *))completionHandler {
    [self.automationEngine getScheduleWithID:identifier completionHandler:completionHandler];
}

- (void)getSchedulesWithMessageID:(NSString *)messageID completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self.automationEngine getSchedulesWithGroup:messageID completionHandler:completionHandler];
}

- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler {
    [self.automationEngine schedule:scheduleInfo completionHandler:completionHandler];;
}

- (void)scheduleMessagesWithScheduleInfo:(NSArray<UAInAppMessageScheduleInfo *> *)scheduleInfos completionHandler:(void (^)(NSArray <UASchedule *> *))completionHandler {
    [self.automationEngine scheduleMultiple:scheduleInfos completionHandler:completionHandler];
}

- (void)cancelMessagesWithID:(NSString *)identifier {
    [self.automationEngine cancelSchedulesWithGroup:identifier];
}

- (void)cancelScheduleWithID:(NSString *)scheduleID {
    [self.automationEngine cancelScheduleWithID:scheduleID];
}

- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAInAppMessageScheduleEdits *)edits
         completionHandler:(void (^)(UASchedule * __nullable))completionHandler {

    [self.automationEngine editScheduleWithID:identifier edits:edits completionHandler:completionHandler];
}

- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder {
    return [[UAInAppMessageScheduleInfo alloc] initWithBuilder:builder];
}

- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^)(UAInAppMessage* message))factory
         forDisplayType:(UAInAppMessageDisplayType)displayType {

    if (factory) {
        self.adapterFactories[@(displayType)] = factory;
    } else {
        [self.adapterFactories removeObjectForKey:@(displayType)];
    }
}

- (void)unlockDisplayAfter:(NSTimeInterval)interval {
    if (interval > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.isDisplayLocked = false;
            [self.automationEngine scheduleConditionsChanged];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isDisplayLocked = false;
            [self.automationEngine scheduleConditionsChanged];
        });
    }
}

- (void)lockDisplay {
    self.isDisplayLocked = true;
}

- (BOOL)isScheduleReadyToExecute:(UASchedule *)schedule {
    UA_LTRACE(@"Checking if schedule %@ is ready to execute.", schedule.identifier);

    // Only ready if active or very soon to be active
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        UA_LTRACE(@"Application is not active. Schedule: %@ not ready", schedule.identifier);
        return NO;
    }

    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAInAppMessageScheduleData *data = self.scheduleData[schedule.identifier];

    if (!data) {
        id<UAInAppMessageAdapterProtocol> (^factory)(UAInAppMessage* message) = self.adapterFactories[@(info.message.displayType)];

        if (!factory) {
            UA_LWARN(@"Factory unavailable for message: %@. Cancelling schedule.", info.message);
            [self cancelScheduleWithID:schedule.identifier];
            return NO;
        }

        id<UAInAppMessageAdapterProtocol> adapter = factory(info.message);

        // If no adapter factory available for specified displayType return NO
        if (!adapter) {
            UA_LWARN(@"Factory failed to build adapter with message: %@. Cancelling schedule.", info.message);
            [self cancelScheduleWithID:schedule.identifier];
            return NO;
        }

        UAInAppMessageScheduleData *data = [UAInAppMessageScheduleData dataWithAdapter:adapter scheduleID:schedule.identifier];
        self.scheduleData[schedule.identifier] = data;
        [self prepareMessageWithScheduleData:data delay:0];
        return NO;
    }

    // If the display is locked via timer return no
    if (self.isDisplayLocked) {
        UA_LTRACE(@"Display is locked. Schedule: %@ not ready.", schedule.identifier);
        return NO;
    }
    if (!data.isPrepareFinished) {
        UA_LTRACE(@"Message not prepared. Schedule %@ is not ready.", schedule.identifier);
        return NO;
    }

    if (![data.adapter isReadyToDisplay]) {
        UA_LTRACE(@"Adapter ready check failed. Schedule: %@ not ready.", schedule.identifier);
        return NO;
    }

    UA_LTRACE(@"Schedule %@ ready!", schedule.identifier);
    return YES;
}

- (void)executeSchedule:(nonnull UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler {

    UA_LTRACE(@"Executing schedule: %@", schedule.identifier);

    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAInAppMessage *message = info.message;
    UAInAppMessageScheduleData *scheduleData = self.scheduleData[schedule.identifier];

    if (!scheduleData) {
        UA_LERR("InAppMessageManager - Missing schedule data for schedule: %@", schedule.identifier);
        completionHandler();
        return;
    }

    if (![UAInAppMessageAudienceChecks checkDisplayAudienceConditions:info.message.audience]) {
        UA_LDEBUG("InAppMessageManager - Message no longer meets audience conditions, schedule: %@", schedule.identifier);
        completionHandler();
        return;
    }

    // Lock Display
    [self lockDisplay];

    // Notify delegate that the message is about to be displayed
    if ([self.delegate respondsToSelector:@selector(messageWillBeDisplayed:scheduleID:)]) {
        [self.delegate messageWillBeDisplayed:message scheduleID:schedule.identifier];
    }

    // Display event
    UAEvent *event = [UAInAppMessageDisplayEvent eventWithMessage:info.message];
    [[UAirship analytics] addEvent:event];

    // Display time timer
    UAActiveTimer *timer = [[UAActiveTimer alloc] init];
    [timer start];

    UA_WEAKIFY(self);
    [scheduleData.adapter display:^(UAInAppMessageResolution *resolution) {
        UA_STRONGIFY(self);
        UA_LDEBUG(@"Schedule %@ finished displaying", schedule.identifier);

        // Resolution event
        [timer stop];
        UAEvent *event = [UAInAppMessageResolutionEvent eventWithMessage:info.message resolution:resolution displayTime:timer.time];
        [[UAirship analytics] addEvent:event];

        // Cancel button
        if (resolution.type == UAInAppMessageResolutionTypeButtonClick && resolution.buttonInfo.behavior == UAInAppMessageButtonInfoBehaviorCancel) {
            [self cancelScheduleWithID:schedule.identifier];
        }

        if (info.message.actions) {
            [UAActionRunner runActionsWithActionValues:info.message.actions
                                             situation:UASituationManualInvocation
                                              metadata:nil
                                     completionHandler:^(UAActionResult *result) {
                                         UA_LTRACE(@"Finished running actions for schedule %@", schedule.identifier);
                                     }];
        }



        // Start timer to unlock display after display interval
        [self unlockDisplayAfter:self.displayInterval];
        [self.scheduleData removeObjectForKey:schedule.identifier];

        // Notify delegate that the message has finished displaying
        if ([self.delegate respondsToSelector:@selector(messageFinishedDisplaying:scheduleID:resolution:)]) {
            [self.delegate messageFinishedDisplaying:message scheduleID:schedule.identifier resolution:resolution];
        }

        completionHandler();
    }];
}

- (void)scheduleExpired:(UASchedule *)schedule {
    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAEvent *event = [UAInAppMessageResolutionEvent eventWithExpiredMessage:info.message expiredDate:info.end];
    [[UAirship analytics] addEvent:event];
}

- (void)prepareMessageWithScheduleData:(UAInAppMessageScheduleData *)scheduleData delay:(NSTimeInterval)delay {
    UA_LDEBUG(@"Preparing schedule: %@ delay: %f", scheduleData.scheduleID, delay);

    UA_WEAKIFY(self);
    NSOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        UA_LDEBUG(@"Operation for schedule: %@ delay: %f", scheduleData.scheduleID, delay);

        dispatch_async(dispatch_get_main_queue(), ^{
            [scheduleData.adapter prepare:^(UAInAppMessagePrepareResult result) {
                UA_STRONGIFY(self);
                UA_LDEBUG(@"Prepare result: %ld schedule: %@", (unsigned long)result, scheduleData.scheduleID);
                switch (result) {
                    case UAInAppMessagePrepareResultSuccess:
                        scheduleData.isPrepareFinished = YES;
                        [self.automationEngine scheduleConditionsChanged];
                        break;

                    case UAInAppMessagePrepareResultRetry:
                        [self prepareMessageWithScheduleData:scheduleData delay:MessagePrepareRetyDelay];
                        break;

                    case UAInAppMessagePrepareResultCancel:
                    default:
                        [self cancelScheduleWithID:scheduleData.scheduleID];
                        [self.scheduleData removeObjectForKey:scheduleData.scheduleID];
                        break;
                }
                [operation finish];
            }];
        });
    }];

    if (delay) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            UA_STRONGIFY(self);
            [self.queue addOperation:operation];
        });
    } else {
        [self.queue addOperation:operation];
    }
}

- (void)onComponentEnableChange {
    [self updateEnginePauseState];
}

- (void)setEnabled:(BOOL)enabled {
    [self.dataStore setBool:enabled forKey:UAInAppMessageManagerEnabledKey];
    [self updateEnginePauseState];
}

- (BOOL)isEnabled {
    return [self.dataStore boolForKey:UAInAppMessageManagerEnabledKey default:YES];
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

@end

NS_ASSUME_NONNULL_END

