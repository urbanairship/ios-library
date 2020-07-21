/* Copyright Airship and Contributors */

#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageFullScreenAdapter.h"
#import "UAInAppMessageModalAdapter.h"
#import "UAInAppMessageHTMLAdapter.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAInAppMessageAudience.h"
#import "UAInAppMessagingRemoteConfig+Internal.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAInAppMessageDefaultDisplayCoordinator.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppMessageImmediateDisplayCoordinator.h"
#import "NSObject+AnonymousKVO+Internal.h"
#import "UAActiveTimer+Internal.h"
#import "UARetriable+Internal.h"
#import "UARetriablePipeline+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const MaxSchedules = 200;

NSString *const UAInAppAutomationStoreFileFormat = @"In-app-automation-%@.sqlite";
NSString *const UAInAppMessageManagerEnabledKey = @"UAInAppMessageManagerEnabled";
NSString *const UAInAppMessageManagerDisplayIntervalKey = @"UAInAppMessageManagerDisplayInterval";
NSString *const UAInAppMessageManagerPausedKey = @"UAInAppMessageManagerPaused";
NSString *const UAInAppMessageDisplayCoordinatorIsReadyKey = @"isReady";

@interface UAInAppMessageScheduleData : NSObject

@property(nonatomic, strong, nonnull) id<UAInAppMessageAdapterProtocol> adapter;
@property(nonatomic, copy, nonnull) NSString *scheduleID;
@property(nonatomic, strong, nonnull) NSDictionary *metadata;
@property(nonatomic, strong, nonnull) UAInAppMessage *message;
@property(nonatomic, strong, nonnull) id<UAInAppMessageDisplayCoordinator> displayCoordinator;

+ (instancetype)dataWithAdapter:(id<UAInAppMessageAdapterProtocol>)adapter
                     scheduleID:(NSString *)scheduleID
                       metadata:(NSDictionary *)metadata
                        message:(UAInAppMessage *)message
             displayCoordinator:(id<UAInAppMessageDisplayCoordinator>)displayCoordinator;

@end

@implementation UAInAppMessageScheduleData

- (instancetype)initWithAdapter:(id<UAInAppMessageAdapterProtocol>)adapter
                     scheduleID:(NSString *)scheduleID
                       metadata:(NSDictionary *)metadata
                        message:(UAInAppMessage *)message
             displayCoordinator:(id<UAInAppMessageDisplayCoordinator>)displayCoordinator {

    self = [super init];

    if (self) {
        self.adapter = adapter;
        self.scheduleID = scheduleID;
        self.message = message;
        self.displayCoordinator = displayCoordinator;
        self.metadata = metadata;
    }

    return self;
}

+ (instancetype)dataWithAdapter:(id<UAInAppMessageAdapterProtocol>)adapter
                     scheduleID:(NSString *)scheduleID
                       metadata:(NSDictionary *)metadata
                        message:(UAInAppMessage *)message
             displayCoordinator:(id<UAInAppMessageDisplayCoordinator>)displayCoordinator {

    return [[self alloc] initWithAdapter:adapter scheduleID:scheduleID metadata:metadata message:message displayCoordinator:displayCoordinator];
}

@end

@interface UAInAppMessageManager ()

@property(nonatomic, strong) NSMutableDictionary *adapterFactories;
@property(nonatomic, strong) UAAutomationEngine *automationEngine;
@property(nonatomic, strong) NSMutableDictionary *adapters;
@property(nonatomic, strong) id<UARemoteDataProvider> remoteDataProvider;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) NSMutableDictionary *scheduleData;
@property(nonatomic, strong) UATagGroupsLookupManager *tagGroupsLookupManager;
@property(nonatomic, strong) UADispatcher *dispatcher;
@property(nonatomic, strong) UARetriablePipeline *prepareSchedulePipeline;
@property(nonatomic, strong) UAInAppMessageDefaultDisplayCoordinator *defaultDisplayCoordinator;
@property(nonatomic, strong) UAInAppMessageImmediateDisplayCoordinator *immediateDisplayCoordinator;
@property(nonatomic, strong) UAAnalytics *analytics;

@end

@implementation UAInAppMessageManager

+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine
                     tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                         remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                    channel:(UAChannel *)channel
                                 dispatcher:(UADispatcher *)dispatcher
                         displayCoordinator:(UAInAppMessageDefaultDisplayCoordinator *)displayCoordinator
                               assetManager:(UAInAppMessageAssetManager *)assetManager
                                  analytics:(UAAnalytics *)analytics {

    return [[self alloc] initWithAutomationEngine:automationEngine
                           tagGroupsLookupManager:tagGroupsLookupManager
                               remoteDataProvider:remoteDataProvider
                                        dataStore:dataStore
                                          channel:channel
                                       dispatcher:dispatcher
                               displayCoordinator:displayCoordinator
                                     assetManager:assetManager
                                        analytics:analytics];
}

+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
                 tagGroupHistorian:(UATagGroupHistorian *)tagGroupHistorian
               remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                        analytics:(UAAnalytics *)analytics {

    NSString *storeName = [NSString stringWithFormat:UAInAppAutomationStoreFileFormat, config.appKey];

    UAAutomationStore *store = [UAAutomationStore automationStoreWithStoreName:storeName scheduleLimit:MaxSchedules];
    UAAutomationEngine *automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:store];

    UATagGroupsLookupManager *lookupManager = [UATagGroupsLookupManager lookupManagerWithConfig:config
                                                                                      dataStore:dataStore
                                                                               tagGroupHistorian:tagGroupHistorian];

    return [[UAInAppMessageManager alloc] initWithAutomationEngine:automationEngine
                                            tagGroupsLookupManager:lookupManager
                                                remoteDataProvider:remoteDataProvider
                                                         dataStore:dataStore
                                                           channel:channel
                                                        dispatcher:[UADispatcher mainDispatcher]
                                                displayCoordinator:[[UAInAppMessageDefaultDisplayCoordinator alloc] init]
                                                      assetManager:[UAInAppMessageAssetManager assetManager]
                                                         analytics:analytics];
}

- (instancetype)initWithAutomationEngine:(UAAutomationEngine *)automationEngine
                  tagGroupsLookupManager:(UATagGroupsLookupManager *)tagGroupsLookupManager
                      remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                               dataStore:(UAPreferenceDataStore *)dataStore
                                 channel:(UAChannel *)channel
                              dispatcher:(UADispatcher *)dispatcher
                      displayCoordinator:(UAInAppMessageDefaultDisplayCoordinator *)displayCoordinator
                            assetManager:(UAInAppMessageAssetManager *)assetManager
                               analytics:(UAAnalytics *)analytics {

    self = [super initWithDataStore:dataStore];

    if (self) {
        self.scheduleData = [NSMutableDictionary dictionary];
        self.adapterFactories = [NSMutableDictionary dictionary];
        self.adapters = [NSMutableDictionary dictionary];
        self.dataStore = dataStore;
        self.automationEngine = automationEngine;
        self.automationEngine.delegate = self;
        self.tagGroupsLookupManager = tagGroupsLookupManager;
        self.tagGroupsLookupManager.delegate = self;
        self.remoteDataProvider = remoteDataProvider;
        self.remoteDataClient = [UAInAppRemoteDataClient clientWithScheduler:self
                                                          remoteDataProvider:remoteDataProvider
                                                                   dataStore:dataStore channel:channel];
        self.dispatcher = dispatcher;
        self.prepareSchedulePipeline = [UARetriablePipeline pipeline];
        self.defaultDisplayCoordinator = displayCoordinator;
        self.defaultDisplayCoordinator.displayInterval = self.displayInterval;
        self.immediateDisplayCoordinator = [UAInAppMessageImmediateDisplayCoordinator coordinator];
        self.assetManager = assetManager;
        self.analytics = analytics;
        [self setDefaultAdapterFactories];

        [self.automationEngine start];
        [self updateEnginePauseState];
    }

    return self;
}

- (void)setDisplayInterval:(NSTimeInterval)displayInterval {
    self.defaultDisplayCoordinator.displayInterval = displayInterval;
    [self.dataStore setInteger:displayInterval forKey:UAInAppMessageManagerDisplayIntervalKey];
}

- (NSTimeInterval)displayInterval {
    if ([self.dataStore objectForKey:UAInAppMessageManagerDisplayIntervalKey]) {
        return [self.dataStore integerForKey:UAInAppMessageManagerDisplayIntervalKey];
    }
    return kUAInAppMessageDefaultDisplayInterval;
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

    [self setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        return [UAInAppMessageHTMLAdapter adapterForMessage:message];
    } forDisplayType:UAInAppMessageDisplayTypeHTML];
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
                  completionHandler:^(UASchedule *schedule) {

        // Schedule the assets
        if (schedule) {
            [self scheduleAssets:@[schedule]];
        }

        completionHandler(schedule);
    }];
}

- (void)scheduleMessagesWithScheduleInfo:(NSArray<UAInAppMessageScheduleInfo *> *)scheduleInfos
                                metadata:(nullable NSDictionary *)metadata
                       completionHandler:(void (^)(NSArray <UASchedule *> *))completionHandler {
    [self.automationEngine scheduleMultiple:scheduleInfos
                                   metadata:metadata
                          completionHandler:^(NSArray<UASchedule *> *schedules) {
        // Schedule the assets
        [self scheduleAssets:schedules];
        completionHandler(schedules);
    }];
}

- (void)scheduleAssets:(NSArray<UASchedule *> *)schedules {
    for (UASchedule *schedule in schedules) {
        [self.assetManager onSchedule:schedule];
    }
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

- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^)(UAInAppMessage* message))factory
         forDisplayType:(UAInAppMessageDisplayType)displayType {

    if (factory) {
        self.adapterFactories[@(displayType)] = factory;
    } else {
        [self.adapterFactories removeObjectForKey:@(displayType)];
    }
}

- (nullable id<UAInAppMessageAdapterProtocol>)createAdapterForMessage:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID {
    id<UAInAppMessageAdapterProtocol> (^factory)(UAInAppMessage* message) = self.adapterFactories[@(message.displayType)];

    if (!factory) {
        UA_LERR(@"Factory unavailable for message: %@", message);
        return nil;
    }

    id<UAInAppMessageAdapterProtocol> adapter = factory(message);
    [self.adapters setObject:adapter forKey:scheduleID];

    return adapter;
}

- (UARetriable *)adapterRetriableWithMessage:(UAInAppMessage *)message scheduleID:(NSString *)scheduleID resultHandler:(UARetriableCompletionHandler)resultHandler {
    UA_WEAKIFY(self)
    return [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler handler) {
        UA_STRONGIFY(self)
        id<UAInAppMessageAdapterProtocol> adapter = [self createAdapterForMessage:message scheduleID:scheduleID];

        if (!adapter) {
            handler(UARetriableResultCancel);
        } else {
            handler(UARetriableResultSuccess);
        }
    } resultHandler:resultHandler];
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

- (UARetriable *)metadataChecksWithSchedule:(UASchedule *)schedule resultHandler:(UARetriableCompletionHandler)resultHandler {
    return [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull handler) {
        if ([self isScheduleInvalid:schedule]) {
            [self.remoteDataClient notifyOnMetadataUpdate:^{
                handler(UARetriableResultInvalidate);
            }];
        } else {
            handler(UARetriableResultSuccess);
        }
    } resultHandler:resultHandler];
}

- (UARetriable *)audienceChecksRetriableWithAudience:(UAInAppMessageAudience *)audience resultHandler:(UARetriableCompletionHandler)resultHandler {
    return [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull handler) {
        [self checkAudience:audience completionHandler:^(BOOL success, NSError *error) {
            if (error) {
                handler(UARetriableResultRetry);
            } else {
                handler(success ? UARetriableResultSuccess : UARetriableResultCancel);
            }
        }];
    } resultHandler:resultHandler];
}

- (UARetriable *)prepareMessageAssetsWithSchedule:(UASchedule *)schedule
                                    resultHandler:(UARetriableCompletionHandler)resultHandler {
    return [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler _Nonnull handler) {
        [self.assetManager onPrepare:schedule completionHandler:^(UAInAppMessagePrepareResult result) {
            switch (result) {
                case UAInAppMessagePrepareResultSuccess:
                    handler(UARetriableResultSuccess);
                    break;
                case UAInAppMessagePrepareResultRetry:
                    handler(UARetriableResultRetry);
                    break;
                case UAInAppMessagePrepareResultCancel:
                    [self.assetManager onDisplayFinished:schedule];
                    handler(UARetriableResultCancel);
                    break;
                case UAInAppMessagePrepareResultInvalidate:
                    handler(UARetriableResultInvalidate);
            }
        }];
    } resultHandler:resultHandler];
}

- (UARetriable *)prepareMessageDataRetriableWithSchedule:(UASchedule *)schedule
                                           resultHandler:(UARetriableCompletionHandler)resultHandler {

    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAInAppMessage *message = info.message;

    id<UAInAppMessageDisplayCoordinator> displayCoordinator = [self displayCoordinatorForMessage:message];

    UA_WEAKIFY(self)
    return [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler handler) {
        UA_STRONGIFY(self)

        id<UAInAppMessageAdapterProtocol> adapter = self.adapters[schedule.identifier];

        if (!adapter) {
            handler(UARetriableResultCancel);
            return;
        }

        UAInAppMessageScheduleData *data = [UAInAppMessageScheduleData dataWithAdapter:adapter
                                                                            scheduleID:schedule.identifier
                                                                              metadata:schedule.metadata
                                                                               message:message
                                                                    displayCoordinator:displayCoordinator];

        [self.assetManager assetsForSchedule:schedule completionHandler:^(UAInAppMessageAssets *assets) {
            [self.dispatcher dispatchAsync:^{
                void (^completionHandler)(UAInAppMessagePrepareResult) = ^void(UAInAppMessagePrepareResult prepareResult) {
                    UA_STRONGIFY(self)
                    UA_LDEBUG(@"Prepare result: %ld schedule: %@", (unsigned long)prepareResult, schedule.identifier);
                    switch (prepareResult) {
                        case UAInAppMessagePrepareResultSuccess:
                            self.scheduleData[schedule.identifier] = data;
                            handler(UARetriableResultSuccess);
                            break;
                        case UAInAppMessagePrepareResultRetry:
                            handler(UARetriableResultRetry);
                            break;
                        case UAInAppMessagePrepareResultCancel:
                            handler(UARetriableResultCancel);
                            break;
                        case UAInAppMessagePrepareResultInvalidate:
                            handler(UARetriableResultInvalidate);
                            break;
                    }
                };
                [adapter prepareWithAssets:assets completionHandler:completionHandler];
            }];
        }];
    } resultHandler:resultHandler];
}

- (void)prepareSchedule:(UASchedule *)schedule completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler {
    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAInAppMessage *message = info.message;

    // Allow the delegate to extend the message if desired.
    id<UAInAppMessagingDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(extendMessage:)]) {
        message = [delegate extendMessage:message];
        if (!message) {
            UA_LERR(@"Error extending message");
            completionHandler(UAAutomationSchedulePrepareResultPenalize);
            return;
        }
    }

    // Check the metadata
    UARetriable *metadataCheck = [self metadataChecksWithSchedule:schedule resultHandler:^(UARetriableResult result) {
        if (result == UARetriableResultInvalidate) {
            completionHandler(UAAutomationSchedulePrepareResultInvalidate);
        }
    }];

    // Create the adapter
    UARetriable *createAdapter = [self adapterRetriableWithMessage:message scheduleID:schedule.identifier resultHandler:^(UARetriableResult result) {
        if (result == UARetriableResultCancel) {
            UA_LDEBUG(@"Failed to build adapter for message: %@, skipping display for schedule: %@", message, schedule.identifier);
            completionHandler(UAAutomationSchedulePrepareResultPenalize);
        }
    }];

    // Check audience conditions
    UARetriable *audienceChecks = [self audienceChecksRetriableWithAudience:message.audience resultHandler:^(UARetriableResult result) {
        if (result == UARetriableResultCancel) {
            UA_LDEBUG(@"Message audience conditions not met, skipping display for schedule: %@, missBehavior: %ld", schedule.identifier, (long)message.audience.missBehavior);
            UAAutomationSchedulePrepareResult prepareResult = UAAutomationSchedulePrepareResultInvalidate;

            switch(message.audience.missBehavior) {
                case UAInAppMessageAudienceMissBehaviorCancel:
                    prepareResult = UAAutomationSchedulePrepareResultCancel;
                    break;
                case UAInAppMessageAudienceMissBehaviorSkip:
                    prepareResult = UAAutomationSchedulePrepareResultSkip;
                    break;
                case UAInAppMessageAudienceMissBehaviorPenalize:
                    prepareResult = UAAutomationSchedulePrepareResultPenalize;
                    break;
            }

            completionHandler(prepareResult);
        }
    }];

    // Prepare the assets
    UARetriable *prepareMessageAssets = [self prepareMessageAssetsWithSchedule:schedule resultHandler:^(UARetriableResult result) {
        UAAutomationSchedulePrepareResult prepareResult = UAAutomationSchedulePrepareResultInvalidate;
        switch (result) {
            case UARetriableResultSuccess:
                return;
            case UARetriableResultRetry:
                prepareResult = UAAutomationSchedulePrepareResultInvalidate;
                break;
            case UARetriableResultCancel:
                prepareResult = UAAutomationSchedulePrepareResultCancel;
                break;
            case UARetriableResultInvalidate:
                prepareResult = UAAutomationSchedulePrepareResultInvalidate;
                break;
        }
        completionHandler(prepareResult);
    }];

    // Prepare the data
    UARetriable *prepareMessageData = [self prepareMessageDataRetriableWithSchedule:schedule resultHandler:^(UARetriableResult result) {
        UAAutomationSchedulePrepareResult prepareResult = UAAutomationSchedulePrepareResultInvalidate;
        switch (result) {
            case UARetriableResultSuccess:
                prepareResult = UAAutomationSchedulePrepareResultContinue;
                break;
            case UARetriableResultRetry:
                prepareResult = UAAutomationSchedulePrepareResultInvalidate;
                break;
            case UARetriableResultCancel:
                prepareResult = UAAutomationSchedulePrepareResultCancel;
                break;
            case UARetriableResultInvalidate:
                prepareResult = UAAutomationSchedulePrepareResultInvalidate;
                break;
        }
        completionHandler(prepareResult);
    }];

    [self.prepareSchedulePipeline addChainedRetriables:@[metadataCheck, createAdapter, audienceChecks, prepareMessageAssets, prepareMessageData]];
}

- (nullable id<UAInAppMessageDisplayCoordinator>)displayCoordinatorForMessage:(UAInAppMessage *)message {
    id<UAInAppMessageDisplayCoordinator> displayCoordinator;
    id<UAInAppMessagingDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(displayCoordinatorForMessage:)]) {
        displayCoordinator = [delegate displayCoordinatorForMessage:message];
    }

    if ([message.displayBehavior isEqualToString:UAInAppMessageDisplayBehaviorImmediate]) {
        displayCoordinator = self.immediateDisplayCoordinator;
    }

    return displayCoordinator ?: self.defaultDisplayCoordinator;
}

/**
 * Checks to see if a schedule from remote-data is still valid.
 *
 * @param schedule The in-app schedule.
 * @return `YES` if the schedule is valid, otherwise `NO`.
 */
-(BOOL)isScheduleInvalid:(UASchedule *)schedule {
    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;

    if (!info || info.message.source != UAInAppMessageSourceRemoteData) {
        return NO;
    }

    if (![self.remoteDataProvider isMetadataCurrent:schedule.metadata]) {
        return YES;
    }

    return NO;
}

- (UAAutomationScheduleReadyResult)isScheduleReadyToExecute:(UASchedule *)schedule {
    UA_LTRACE(@"Checking if schedule %@ is ready to execute.", schedule.identifier);

    UAInAppMessageScheduleData *data = self.scheduleData[schedule.identifier];

    NSObject<UAInAppMessageDisplayCoordinator> *displayCoordinator = (NSObject<UAInAppMessageDisplayCoordinator>*)data.displayCoordinator;

    // If manager is paused
    if (self.isPaused) {
        UA_LTRACE(@"Message display is currently paused. Schedule: %@ not ready.", schedule.identifier);
        return UAAutomationScheduleReadyResultNotReady;
    }

    if (!data) {
        UA_LERR("No data for schedule: %@", schedule.identifier);
        return UAAutomationScheduleReadyResultNotReady;
    }

    // If display coordinator puts back pressure on display, check again when it's ready
    if (![displayCoordinator isReady]) {
        UA_LTRACE(@"Display coordinator %@ not ready. Retrying schedule %@ later.", displayCoordinator, schedule.identifier);
        __block UADisposable *disposable = [displayCoordinator observeAtKeyPath:UAInAppMessageDisplayCoordinatorIsReadyKey withBlock:^(id value) {
            if ([value boolValue]) {
                [self.automationEngine scheduleConditionsChanged];
                [disposable dispose];
            }
        }];

        return UAAutomationScheduleReadyResultNotReady;
    }

    if ([self isScheduleInvalid:schedule]) {
        UA_LTRACE(@"Metadata is out of date, invalidating schedule with id: %@ until refresh can occur.", schedule.identifier);
        [self.adapters removeObjectForKey:schedule.identifier];
        return UAAutomationScheduleReadyResultInvalidate;
    }

    if (![data.adapter isReadyToDisplay]) {
        UA_LTRACE(@"Adapter ready check failed. Schedule: %@ not ready.", schedule.identifier);
        return UAAutomationScheduleReadyResultNotReady;
    }

    UA_LTRACE(@"Schedule %@ ready!", schedule.identifier);
    return UAAutomationScheduleReadyResultContinue;
}

- (void)executeSchedule:(nonnull UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler {

    UA_LTRACE(@"Executing schedule: %@", schedule.identifier);

    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAInAppMessage *message = info.message;
    UAInAppMessageScheduleData *scheduleData = self.scheduleData[schedule.identifier];

    if (!scheduleData) {
        completionHandler();
        return;
    }

    id<UAInAppMessageAdapterProtocol> adapter = scheduleData.adapter;
    id<UAInAppMessageDisplayCoordinator> displayCoordinator = scheduleData.displayCoordinator;

    // Notify delegate that the message is about to be displayed
    id<UAInAppMessagingDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(messageWillBeDisplayed:scheduleID:)]) {
        [delegate messageWillBeDisplayed:message scheduleID:schedule.identifier];
    }

    if (info.message.isReportingEnabled) {
        // Display event
        UAEvent *event = [UAInAppMessageDisplayEvent eventWithMessage:message];
        [self.analytics addEvent:event];
    }

    // Display time timer
    UAActiveTimer *timer = [[UAActiveTimer alloc] init];
    [timer start];

    // Notify the coordinator that message display has begin
    if ([displayCoordinator respondsToSelector:@selector(didBeginDisplayingMessage:)]) {
        [displayCoordinator didBeginDisplayingMessage:message];
    }

    // After display has finished, notify the coordinator as well
    completionHandler = ^{
        if ([displayCoordinator respondsToSelector:@selector(didFinishDisplayingMessage:)]) {
            [displayCoordinator didFinishDisplayingMessage:message];
        }
        completionHandler();
    };

    UA_WEAKIFY(self);
    void (^displayCompletionHandler)(UAInAppMessageResolution *) = ^(UAInAppMessageResolution *resolution) {
        UA_STRONGIFY(self);
        UA_LDEBUG(@"Schedule %@ finished displaying", schedule.identifier);

        [self.adapters removeObjectForKey:schedule.identifier];

        // Resolution event
        [timer stop];
        UAEvent *event = [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:timer.time];

        if (info.message.isReportingEnabled) {
            [self.analytics addEvent:event];
        }

        // Cancel button
        if (resolution.type == UAInAppMessageResolutionTypeButtonClick && resolution.buttonInfo.behavior == UAInAppMessageButtonInfoBehaviorCancel) {
            [self cancelScheduleWithID:schedule.identifier];
        }

        if (message.actions) {
            [UAActionRunner runActionsWithActionValues:message.actions
                                             situation:UASituationManualInvocation
                                              metadata:nil
                                     completionHandler:^(UAActionResult *result) {
                UA_LTRACE(@"Finished running actions for schedule %@", schedule.identifier);
            }];
        }

        [self.scheduleData removeObjectForKey:schedule.identifier];

        // Notify delegate that the message has finished displaying
        id<UAInAppMessagingDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(messageFinishedDisplaying:scheduleID:resolution:)]) {
            [delegate messageFinishedDisplaying:message scheduleID:schedule.identifier resolution:resolution];
        }

        // notify the asset manager
        [self.assetManager onDisplayFinished:schedule];

        completionHandler();
    };

    [adapter display:displayCompletionHandler];
}

- (void)onScheduleExpired:(UASchedule *)schedule {
    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    UAEvent *event = [UAInAppMessageResolutionEvent eventWithExpiredMessage:info.message expiredDate:info.end];

    if (info.message.isReportingEnabled) {
        [self.analytics addEvent:event];
    }

    [self.assetManager onScheduleFinished:schedule];
}

- (void)onScheduleCancelled:(UASchedule *)schedule {
    [self.assetManager onScheduleFinished:schedule];
}

- (void)onScheduleLimitReached:(UASchedule *)schedule {
    [self.assetManager onScheduleFinished:schedule];
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

@end

NS_ASSUME_NONNULL_END


