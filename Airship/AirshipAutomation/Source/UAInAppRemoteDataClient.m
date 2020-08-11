/* Copyright Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UASchedule+Internal.h"
#import "UAInAppMessageSchedule.h"
#import "UAInAppMessageManager.h"
#import "UAScheduleAudienceChecks+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "NSObject+AnonymousKVO+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "NSDictionary+UAAdditions.h"

static NSString * const UAInAppMessagesLastPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
static NSString * const UAInAppMessagesLastPayloadMetadataKey = @"UAInAppRemoteDataClient.LastPayloadMetadata";

static NSString * const UAInAppMessagesScheduledNewUserCutoffTimeKey = @"UAInAppRemoteDataClient.ScheduledNewUserCutoffTime";
static NSString * const UAInAppRemoteDataClientMetadataKey = @"com.urbanairship.iaa.REMOTE_DATA_METADATA";

//static NSString * const UAInAppMessagesScheduledMessagesKey = @"UAInAppRemoteDataClient.ScheduledMessages";



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
static NSString *const UAScheduleInfoInAppMessageKey = @"message";
static NSString *const UAScheduleInfoAudienceKey = @"audience";

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
                                       completionHandler:^(UASchedule *schedule) {
                dispatch_group_leave(dispatchGroup);
                if (schedule) {
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
                            completionHandler:^(UASchedule *schedule) {
                dispatch_group_leave(dispatchGroup);
                if (schedule) {
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

+ (UASchedule *)parseScheduleWithJSON:(id)json
                             metadata:(NSDictionary *)metadata {
    NSDictionary *data = [json dictionaryForKey:UAScheduleInfoInAppMessageKey defaultValue:nil];
    if (!data) {
        UA_LERR(@"Invalid message: %@", json);
        return nil;
    }

    NSError *messageError;
    UAInAppMessage *message = [UAInAppMessage messageWithJSON:data
                                                defaultSource:UAInAppMessageSourceRemoteData
                                                        error:&messageError];

    if (!message || messageError) {
        UA_LERR(@"Invalid message: %@ - %@", json, messageError);
        return nil;
    }

    // Triggers
    NSMutableArray *triggers = [NSMutableArray array];
    for (id triggerJSON in [json arrayForKey:UAScheduleInfoTriggersKey defaultValue:nil]) {
        NSError *triggerError;
        UAScheduleTrigger *trigger = [UAScheduleTrigger triggerWithJSON:triggerJSON error:&triggerError];
        if (triggerError || !trigger) {
            UA_LERR(@"Invalid schedule: %@ - %@", json, triggerError);
            return nil;
        }
        [triggers addObject:trigger];
    }

    // Delay
    UAScheduleDelay *delay = nil;
    if (json[UAScheduleInfoDelayKey]) {
        NSError *delayError;
        UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:json[UAScheduleInfoDelayKey] error:&delayError];
        if (delayError || !delay) {
            UA_LERR(@"Invalid schedule: %@ - %@", json, delayError);
            return nil;
        }
    }

    UAScheduleAudience *audience;
    id audienceDict = [data dictionaryForKey:UAScheduleInfoAudienceKey defaultValue:nil];
    if (audienceDict) {
        NSError *audienceError;
        audience = [UAScheduleAudience audienceWithJSON:audienceDict error:&audienceError];

        if (audienceError) {
            UA_LERR(@"Invalid audience: %@ - %@", json, audienceError);
            return nil;
        }
    }

    return [UAInAppMessageSchedule scheduleWithMessage:message
                                          builderBlock:^(UAScheduleBuilder *builder) {

        builder.identifier = [UAInAppRemoteDataClient parseScheduleID:json];
        builder.metadata = metadata;
        builder.triggers = triggers;
        builder.delay = delay;
        builder.group = [json stringForKey:UAScheduleInfoGroupKey defaultValue:nil];
        builder.limit = [[json numberForKey:UAScheduleInfoLimitKey defaultValue:@(1)] unsignedIntegerValue];
        builder.priority = [[json numberForKey:UAScheduleInfoPriorityKey defaultValue:nil] integerValue];
        builder.editGracePeriod = [[json numberForKey:UAScheduleInfoEditGracePeriodKey defaultValue:nil] doubleValue];
        builder.interval = [[json numberForKey:UAScheduleInfoIntervalKey defaultValue:nil] doubleValue];
        builder.audience = audience;

        if (json[UAScheduleInfoStartKey]) {
            builder.start = [UAUtils parseISO8601DateFromString:[json stringForKey:UAScheduleInfoStartKey defaultValue:@""]];
        }

        if (json[UAScheduleInfoEndKey]) {
            builder.end = [UAUtils parseISO8601DateFromString:[json stringForKey:UAScheduleInfoEndKey defaultValue:@""]];
        }
    }];
}

+ (NSString *)parseScheduleID:(id)json {
    id messagePayload = json[UAScheduleInfoInAppMessageKey];
    if (!messagePayload) {
        return nil;
    }

    return messagePayload[UAInAppMessageIDKey];
}

+ (UAScheduleEdits *)parseScheduleEditsWithJSON:(id)json metadata:(NSDictionary *)metadata {
    NSDictionary *data = [json dictionaryForKey:UAScheduleInfoInAppMessageKey defaultValue:nil];
    if (!data) {
        UA_LERR(@"Invalid message: %@", json);
        return nil;
    }

    NSError *messageError;
    UAInAppMessage *message = [UAInAppMessage messageWithJSON:data
                                                defaultSource:UAInAppMessageSourceRemoteData
                                                        error:&messageError];
    
    if (!message || messageError) {
        UA_LERR(@"Invalid message: %@ - %@", json, messageError);
        return nil;
    }

    UAScheduleAudience *audience;
    id audienceDict = [data dictionaryForKey:UAScheduleInfoAudienceKey defaultValue:nil];
    if (audienceDict) {
        NSError *audienceError;
        audience = [UAScheduleAudience audienceWithJSON:audienceDict error:&audienceError];

        if (audienceError) {
            UA_LERR(@"Invalid audience: %@ - %@", json, audienceError);
            return nil;
        }
    }

    return [UAScheduleEdits editsWithMessage:message builderBlock:^(UAScheduleEditsBuilder * _Nonnull builder) {
        builder.metadata = metadata;
        builder.limit = [json numberForKey:UAScheduleInfoLimitKey defaultValue:nil];
        builder.priority = [json numberForKey:UAScheduleInfoPriorityKey defaultValue:nil];
        builder.editGracePeriod = [json numberForKey:UAScheduleInfoEditGracePeriodKey defaultValue:nil];
        builder.interval = [json numberForKey:UAScheduleInfoIntervalKey defaultValue:nil];
        builder.audience = audience;

        /*
         * Since we cancel a schedule by setting the end time and start time to the payload's last modified timestamp,
         * we need to reset them back if the edits do not update them.
         */

        if (json[UAScheduleInfoStartKey]) {
            builder.start = [UAUtils parseISO8601DateFromString:[json stringForKey:UAScheduleInfoStartKey defaultValue:@""]];
        } else {
            builder.start = [NSDate distantPast];
        }

        if (json[UAScheduleInfoEndKey]) {
            builder.end = [UAUtils parseISO8601DateFromString:[json stringForKey:UAScheduleInfoEndKey defaultValue:@""]];
        } else {
            builder.end = [NSDate distantFuture];
        }
    }];
}

@end

