/* Copyright Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UASchedule+Internal.h"
#import "UAInAppMessageSchedule.h"
#import "UAInAppMessageManager.h"
#import "UAScheduleAudienceChecks+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "NSDictionary+UAAdditions.h"
#import "UAActionSchedule.h"
#import "UADeferredSchedule+Internal.h"

static NSString * const UAInAppMessagesLastPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
static NSString * const UAInAppMessagesLastPayloadMetadataKey = @"UAInAppRemoteDataClient.LastPayloadMetadata";

static NSString * const UAInAppMessagesScheduledNewUserCutoffTimeKey = @"UAInAppRemoteDataClient.ScheduledNewUserCutoffTime";
static NSString * const UAInAppRemoteDataClientMetadataKey = @"com.urbanairship.iaa.REMOTE_DATA_METADATA";

static NSString * const UAInAppMessages = @"in_app_messages";
static NSString * const UAInAppMessagesCreatedJSONKey = @"created";
static NSString * const UAInAppMessagesUpdatedJSONKey = @"last_updated";

static NSString *const UAScheduleInfoPriorityKey = @"priority";
static NSString *const UAScheduleInfoLimitKey = @"limit";
static NSString *const UAScheduleInfoGroupKey = @"group";
static NSString *const UAScheduleInfoEndKey = @"end";
static NSString *const UAScheduleInfoStartKey = @"start";
static NSString *const UAScheduleInfoTriggersKey = @"triggers";
static NSString *const UAScheduleInfoDelayKey = @"delay";
static NSString *const UAScheduleInfoIntervalKey = @"interval";
static NSString *const UAScheduleInfoEditGracePeriodKey = @"edit_grace_period";
static NSString *const UAScheduleInfoAudienceKey = @"audience";
static NSString *const UAScheduleInfoIDKey = @"id";
static NSString *const UAScheduleInfoLegacyIDKey = @"message_id";
static NSString *const UAScheduleInfoTypeKey = @"type";

static NSString *const UAScheduleInfoTypeActions = @"actions";
static NSString *const UAScheduleInfoTypeDeferred = @"deferred";
static NSString *const UAScheduleInfoTypeInAppMessage = @"in_app_message";

static NSString *const UAScheduleInfoInAppMessageKey = @"message";
static NSString *const UAScheduleInfoActionsKey = @"actions";
static NSString *const UAScheduleInfoDeferredKey = @"deferred";

static NSString *const UAScheduleInfoCampaignsKey = @"campaigns";



@interface UAInAppRemoteDataClient()
@property(nonatomic, strong) UAInAppMessageManager *inAppMessageManager;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UADisposable *remoteDataSubscription;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) id<UARemoteDataProvider> remoteDataProvider;
@property(nonatomic, copy) NSDate *scheduleNewUserCutOffTime;
@property(nonatomic, copy) NSDictionary *lastPayloadMetadata;
@end

@implementation UAInAppRemoteDataClient

- (instancetype)initWithRemoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                   channel:(UAChannel *)channel
                            operationQueue:(NSOperationQueue *)operationQueue {

    self = [super init];

    if (self) {
        self.operationQueue = operationQueue;
        self.remoteDataProvider = remoteDataProvider;
        self.dataStore = dataStore;
        if (!self.scheduleNewUserCutOffTime) {
            self.scheduleNewUserCutOffTime = (channel.identifier) ? [NSDate distantPast] : [NSDate date];
        }
    }

    return self;
}

+ (instancetype)clientWithRemoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                   dataStore:(UAPreferenceDataStore *)dataStore
                                     channel:(UAChannel *)channel {

    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    operationQueue.maxConcurrentOperationCount = 1;

    return [[UAInAppRemoteDataClient alloc] initWithRemoteDataProvider:remoteDataProvider
                                                             dataStore:dataStore
                                                               channel:channel
                                                        operationQueue:operationQueue];
}

+ (instancetype)clientWithRemoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                   dataStore:(UAPreferenceDataStore *)dataStore
                                     channel:(UAChannel *)channel
                              operationQueue:(NSOperationQueue *)operationQueue {

    return [[UAInAppRemoteDataClient alloc] initWithRemoteDataProvider:remoteDataProvider
                                                             dataStore:dataStore
                                                               channel:channel
                                                        operationQueue:operationQueue];
}

- (void)subscribe {
    UA_WEAKIFY(self);
    self.remoteDataSubscription = [self.remoteDataProvider subscribeWithTypes:@[UAInAppMessages]
                                                                   block:^(NSArray<UARemoteDataPayload *> * _Nonnull messagePayloads) {
        UA_STRONGIFY(self);
        [self.operationQueue addOperationWithBlock:^{
            UA_STRONGIFY(self);
            [self processInAppMessageData:[messagePayloads firstObject]];
        }];
    }];
}

- (void)dealloc {
    [self.remoteDataSubscription dispose];
}

- (void)notifyOnUpdate:(void (^)(void))completionHandler {
    [self.operationQueue addOperationWithBlock:^{
        if ([self.remoteDataProvider isMetadataCurrent:self.lastPayloadMetadata]) {
            completionHandler();
        } else {
            // Otherwise wait until change to lastPayloadMetadata to invalidate
            __block UADisposable *disposable = [self observeAtKeyPath:@"lastPayloadMetadata" withBlock:^(id  _Nonnull value) {
                completionHandler();
                [disposable dispose];
            }];
        }
    }];
}

- (void)processInAppMessageData:(UARemoteDataPayload *)messagePayload {
    NSDate *payloadTimestamp = messagePayload.timestamp;
    NSDictionary *payloadMetadata = messagePayload.metadata ?: @{};

    NSDate *lastPayloadTimestamp = [self.dataStore objectForKey:UAInAppMessagesLastPayloadTimeStampKey] ?: [NSDate distantPast];
    NSDictionary *lastPayloadMetadata = self.lastPayloadMetadata;

    NSDictionary *scheduleMetadata = @{ UAInAppRemoteDataClientMetadataKey: payloadMetadata };

    BOOL isMetadataCurrent = [lastPayloadMetadata isEqualToDictionary:payloadMetadata];

    // Skip if the payload timestamp is same as the last updated timestamp and metadata is current
    if ([payloadTimestamp isEqualToDate:lastPayloadTimestamp] && isMetadataCurrent) {
        return;
    }

    // Get the in-app message data, if it exists
    NSArray *messages;
    if (!messagePayload.data || !messagePayload.data[UAInAppMessages] || ![messagePayload.data[UAInAppMessages] isKindOfClass:[NSArray class]]) {
        messages = @[];
    } else {
        messages = messagePayload.data[UAInAppMessages];
    }

    NSArray<NSString *> *currentScheduleIDs = [self getCurrentRemoteScheduleIDs];
    NSMutableArray<NSString *> *scheduleIDs = [NSMutableArray array];
    NSMutableArray<UASchedule *> *newSchedules = [NSMutableArray array];

    // Dispatch group
    dispatch_group_t dispatchGroup = dispatch_group_create();

    // Validate messages and create new schedules
    for (NSDictionary *message in messages) {
        NSDate *createdTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesCreatedJSONKey]];
        NSDate *lastUpdatedTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesUpdatedJSONKey]];

        if (!createdTimeStamp || !lastUpdatedTimeStamp) {
            UA_LERR(@"Failed to parse in-app message timestamps: %@", message);
            continue;
        }

        NSString *scheduleID = [UAInAppRemoteDataClient parseScheduleID:message];
        if (!scheduleID.length) {
            UA_LERR("Missing ID: %@", message);
            continue;
        }

        [scheduleIDs addObject:scheduleID];

        // Ignore any messages that have not updated since the last payload
        if (isMetadataCurrent && [lastPayloadTimestamp compare:lastUpdatedTimeStamp] != NSOrderedAscending) {
            continue;
        }

        if ([createdTimeStamp compare:lastPayloadTimestamp] == NSOrderedDescending) {
            // New in-app message
            UASchedule *schedule = [UAInAppRemoteDataClient parseScheduleWithJSON:message
                                                                         metadata:scheduleMetadata];
            if (!schedule) {
                UA_LERR(@"Failed to parse in-app automation: %@", message);
                continue;
            }

            if ([self checkSchedule:schedule createdTimeStamp:createdTimeStamp]) {
                [newSchedules addObject:schedule];
            }

        } else if ([currentScheduleIDs containsObject:scheduleID]) {
            UAScheduleEdits *edits = [UAInAppRemoteDataClient parseScheduleEditsWithJSON:message
                                                                                metadata:scheduleMetadata];

            if (!edits) {
                UA_LERR(@"Failed to parse in-app automation edits: %@", message);
                continue;
            }

            dispatch_group_enter(dispatchGroup);
            [self.delegate editScheduleWithID:scheduleID
                                        edits:edits
                                       completionHandler:^(BOOL result) {
                dispatch_group_leave(dispatchGroup);
                if (result) {
                    UA_LTRACE("Updated in-app automation: %@", scheduleID);
                }
            }];
        }
    }

    // End any messages that are no longer in the listing
    NSMutableArray<NSString *> *deletedScheduleIDS = [NSMutableArray arrayWithArray:currentScheduleIDs];
    [deletedScheduleIDS removeObjectsInArray:scheduleIDs];

    if (deletedScheduleIDS.count) {
        /* To cancel, set the end time to the payload's last modified timestamp. To avoid validation errors,
         The start must be equal to or before the end time. If the schedule comes back, we will reset the start and end time
         from the schedule edits. */
        UAScheduleEdits *edits = [UAScheduleEdits editsWithBuilderBlock:^(UAScheduleEditsBuilder * _Nonnull builder) {
            builder.end = payloadTimestamp;
            builder.start = payloadTimestamp;
        }];

        for (NSString *scheduleID in deletedScheduleIDS) {
            dispatch_group_enter(dispatchGroup);
            [self.delegate editScheduleWithID:scheduleID
                                        edits:edits
                            completionHandler:^(BOOL result) {
                dispatch_group_leave(dispatchGroup);
                if (result) {
                    UA_LTRACE("Ended in-app automation: %@", scheduleID);
                }
            }];
        }
    }

    // New messages
    if (newSchedules.count) {
        dispatch_group_enter(dispatchGroup);
        [self.delegate scheduleMultiple:newSchedules completionHandler:^(BOOL result) {
            dispatch_group_leave(dispatchGroup);
        }];
    }

    // Wait for everything to finish
    dispatch_group_wait(dispatchGroup,  DISPATCH_TIME_FOREVER);

    // Save state
    self.lastPayloadMetadata = payloadMetadata;
    [self.dataStore setObject:payloadTimestamp forKey:UAInAppMessagesLastPayloadTimeStampKey];
}

- (NSDictionary *)lastPayloadMetadata {
    return [self.dataStore objectForKey:UAInAppMessagesLastPayloadMetadataKey] ?: @{};
}

- (void)setLastPayloadMetadata:(NSDictionary *)metadata {
    [self willChangeValueForKey:@"lastPayloadMetadata"];
    [self.dataStore setObject:metadata forKey:UAInAppMessagesLastPayloadMetadataKey];
    [self didChangeValueForKey:@"lastPayloadMetadata"];
}

- (BOOL)checkSchedule:(UASchedule *)schedule createdTimeStamp:(NSDate *)createdTimeStamp {
    UAScheduleAudience *audience = schedule.audience;
    BOOL isNewUser = ([createdTimeStamp compare:self.scheduleNewUserCutOffTime] == NSOrderedAscending);
    return [UAScheduleAudienceChecks checkScheduleAudienceConditions:audience isNewUser:isNewUser];
}

- (NSDate *)scheduleNewUserCutOffTime {
    return [self.dataStore objectForKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

- (void)setScheduleNewUserCutOffTime:(NSDate *)time {
    [self.dataStore setObject:time forKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

- (NSArray<NSString *> *)getCurrentRemoteScheduleIDs {
    NSMutableArray *currentScheduleIDs = [NSMutableArray array];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    UA_WEAKIFY(self)
    [self.delegate getSchedules:^(NSArray<UASchedule *> *schedules) {
        UA_STRONGIFY(self)
        for (UASchedule *schedule in schedules) {
            if ([self isRemoteSchedule:schedule]) {
                [currentScheduleIDs addObject:schedule.identifier];
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return currentScheduleIDs;
}


- (BOOL)isRemoteSchedule:(UASchedule *)schedule {
    if (schedule.metadata[UAInAppRemoteDataClientMetadataKey]) {
        return YES;
    }

    // Legacy way of determining a remote-data schedule
    if (schedule.type == UAScheduleTypeInAppMessage) {
        UAInAppMessage *message = (UAInAppMessage *)schedule.data;
        return message.source == UAInAppMessageSourceRemoteData;
    }

    return NO;
}

- (BOOL)isScheduleUpToDate:(UASchedule *)schedule {
    if (!schedule.metadata) {
        return NO;
    }

    return [self.remoteDataProvider isMetadataCurrent:schedule.metadata[UAInAppRemoteDataClientMetadataKey]];
}

+ (UASchedule *)parseScheduleWithJSON:(id)JSON
                             metadata:(NSDictionary *)metadata {
    // Triggers
    NSMutableArray *triggers = [NSMutableArray array];
    for (id triggerJSON in [JSON arrayForKey:UAScheduleInfoTriggersKey defaultValue:nil]) {
        NSError *triggerError;
        UAScheduleTrigger *trigger = [UAScheduleTrigger triggerWithJSON:triggerJSON error:&triggerError];
        if (triggerError || !trigger) {
            UA_LERR(@"Invalid schedule: %@ - %@", JSON, triggerError);
            return nil;
        }
        [triggers addObject:trigger];
    }

    // Delay
    UAScheduleDelay *delay = nil;
    if (JSON[UAScheduleInfoDelayKey]) {
        NSError *delayError;
        delay = [UAScheduleDelay delayWithJSON:JSON[UAScheduleInfoDelayKey] error:&delayError];
        if (delayError || !delay) {
            UA_LERR(@"Invalid schedule: %@ - %@", JSON, delayError);
            return nil;
        }
    }


    NSError *audienceError;
    UAScheduleAudience *audience = [UAInAppRemoteDataClient parseAudience:JSON error:&audienceError];
    if (audienceError) {
        UA_LERR(@"Invalid schedule: %@ - %@", JSON, audienceError);
        return nil;
    }

    return [UAInAppRemoteDataClient scheduleWithJSON:JSON builderBlock:^(UAScheduleBuilder *builder) {
        builder.identifier = [UAInAppRemoteDataClient parseScheduleID:JSON];
        builder.metadata = metadata;
        builder.triggers = triggers;
        builder.delay = delay;
        builder.group = [JSON stringForKey:UAScheduleInfoGroupKey defaultValue:nil];
        builder.limit = [[JSON numberForKey:UAScheduleInfoLimitKey defaultValue:@(1)] unsignedIntegerValue];
        builder.priority = [[JSON numberForKey:UAScheduleInfoPriorityKey defaultValue:nil] integerValue];
        builder.editGracePeriod = [[JSON numberForKey:UAScheduleInfoEditGracePeriodKey defaultValue:nil] doubleValue];
        builder.interval = [[JSON numberForKey:UAScheduleInfoIntervalKey defaultValue:nil] doubleValue];
        builder.campaigns = [JSON dictionaryForKey:UAScheduleInfoCampaignsKey defaultValue:nil];
        builder.audience = audience;

        if (JSON[UAScheduleInfoStartKey]) {
            builder.start = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoStartKey defaultValue:@""]];
        }

        if (JSON[UAScheduleInfoEndKey]) {
            builder.end = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoEndKey defaultValue:@""]];
        }
    }];
}

+ (UAScheduleEdits *)parseScheduleEditsWithJSON:(id)JSON metadata:(NSDictionary *)metadata {
    NSError *audienceError;
    UAScheduleAudience *audience = [UAInAppRemoteDataClient parseAudience:JSON error:&audienceError];
    if (audienceError) {
        UA_LERR(@"Invalid schedule: %@ - %@", JSON, audienceError);
        return nil;
    }

    return [UAInAppRemoteDataClient editsWithJSON:JSON builderBlock:^(UAScheduleEditsBuilder * _Nonnull builder) {
        builder.metadata = metadata;
        builder.limit = [JSON numberForKey:UAScheduleInfoLimitKey defaultValue:nil];
        builder.priority = [JSON numberForKey:UAScheduleInfoPriorityKey defaultValue:nil];
        builder.editGracePeriod = [JSON numberForKey:UAScheduleInfoEditGracePeriodKey defaultValue:nil];
        builder.interval = [JSON numberForKey:UAScheduleInfoIntervalKey defaultValue:nil];
        builder.audience = audience;

        /*
         * Since we cancel a schedule by setting the end time and start time to the payload's last modified timestamp,
         * we need to reset them back if the edits do not update them.
         */

        if (JSON[UAScheduleInfoStartKey]) {
            builder.start = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoStartKey defaultValue:@""]];
        } else {
            builder.start = [NSDate distantPast];
        }

        if (JSON[UAScheduleInfoEndKey]) {
            builder.end = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoEndKey defaultValue:@""]];
        } else {
            builder.end = [NSDate distantFuture];
        }
    }];
}

+ (NSString *)parseScheduleID:(id)JSON {
    NSString *scheduleID = [JSON stringForKey:UAScheduleInfoIDKey defaultValue:nil];
    if (!scheduleID) {
        NSDictionary *messagePayload = [JSON dictionaryForKey:UAScheduleInfoInAppMessageKey defaultValue:nil];
        scheduleID = [messagePayload stringForKey:UAScheduleInfoLegacyIDKey defaultValue:nil];
    }

    return scheduleID;
}

+ (UAScheduleAudience *)parseAudience:(id)JSON error:(NSError **)error {
    id audienceDict = [JSON dictionaryForKey:UAScheduleInfoAudienceKey defaultValue:nil];
    if (!audienceDict) {
        NSDictionary *messagePayload = [JSON dictionaryForKey:UAScheduleInfoInAppMessageKey defaultValue:nil];
        audienceDict = [messagePayload dictionaryForKey:UAScheduleInfoAudienceKey defaultValue:nil];
    }

    if (audienceDict) {
        return [UAScheduleAudience audienceWithJSON:audienceDict error:error];
    }

    return nil;
}

+ (UASchedule *)scheduleWithJSON:(id)JSON
                    builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock {

    NSString *type = [JSON stringForKey:UAScheduleInfoTypeKey defaultValue:UAScheduleInfoTypeInAppMessage];
    NSError *error;

    if ([type isEqualToString:UAScheduleInfoTypeInAppMessage]) {
        NSDictionary *data = [JSON dictionaryForKey:UAScheduleInfoInAppMessageKey defaultValue:nil];
        if (data) {
            UAInAppMessage *message = [UAInAppMessage messageWithJSON:data
                                                        defaultSource:UAInAppMessageSourceRemoteData
                                                                error:&error];
            if (!error && message) {
                return [UAInAppMessageSchedule scheduleWithMessage:message
                                                      builderBlock:builderBlock];
            }
        }
    } else if ([type isEqualToString:UAScheduleInfoTypeDeferred]) {
        NSDictionary *data = [JSON dictionaryForKey:UAScheduleInfoDeferredKey defaultValue:nil];
        if (data) {
            UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:data
                                                                                      error:&error];
            if (!error && deferred) {
                return [UADeferredSchedule scheduleWithDeferredData:deferred
                                                       builderBlock:builderBlock];
            }
        }
    } else if ([type isEqualToString:UAScheduleInfoTypeActions]) {
        NSDictionary *actions = [JSON dictionaryForKey:UAScheduleInfoActionsKey defaultValue:nil];
        if (actions) {
            return [UAActionSchedule scheduleWithActions:actions builderBlock:builderBlock];
        }
    }

    UA_LERR(@"Invalid schedule: %@ error: %@", JSON, error);
    return nil;
}

+ (UAScheduleEdits *)editsWithJSON:(id)JSON
                      builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {

    NSString *type = [JSON stringForKey:UAScheduleInfoTypeKey defaultValue:UAScheduleInfoTypeInAppMessage];
    NSError *error;

    if ([type isEqualToString:UAScheduleInfoTypeInAppMessage]) {
        NSDictionary *data = [JSON dictionaryForKey:UAScheduleInfoInAppMessageKey defaultValue:nil];
        if (data) {
            UAInAppMessage *message = [UAInAppMessage messageWithJSON:data
                                                        defaultSource:UAInAppMessageSourceRemoteData
                                                                error:&error];
            if (!error && message) {
                return [UAScheduleEdits editsWithMessage:message builderBlock:builderBlock];
            }
        }
    } else if ([type isEqualToString:UAScheduleInfoTypeDeferred]) {
        NSDictionary *data = [JSON dictionaryForKey:UAScheduleInfoDeferredKey defaultValue:nil];
        if (data) {
            UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:data
                                                                                      error:&error];
            if (!error && deferred) {
                return [UAScheduleEdits editsWithDeferredData:deferred builderBlock:builderBlock];
            }
        }
    } else if ([type isEqualToString:UAScheduleInfoTypeActions]) {
        NSDictionary *actions = [JSON dictionaryForKey:UAScheduleInfoActionsKey defaultValue:nil];
        if (actions) {
            return [UAScheduleEdits editsWithActions:actions builderBlock:builderBlock];
        }
    }

    UA_LERR(@"Invalid schedule: %@ error: %@", JSON, error);
    return nil;
}

@end
