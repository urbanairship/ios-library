/* Copyright Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageScheduleEdits+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "NSObject+AnonymousKVO+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

static NSString * const UAInAppMessages = @"in_app_messages";
static NSString * const UAInAppMessagesCreatedJSONKey = @"created";
static NSString * const UAInAppMessagesUpdatedJSONKey = @"last_updated";
static NSString * const UAInAppMessagesLastPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
static NSString * const UAInAppMessagesLastPayloadMetadataKey = @"UAInAppRemoteDataClient.LastPayloadMetadata";
static NSString * const UAInAppMessagesScheduledMessagesKey = @"UAInAppRemoteDataClient.ScheduledMessages";
static NSString * const UAInAppMessagesScheduledNewUserCutoffTimeKey = @"UAInAppRemoteDataClient.ScheduledNewUserCutoffTime";
static NSString * const UAInAppRemoteDataClientMetadataKey = @"com.urbanairship.iaa.REMOTE_DATA_METADATA";

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

    BOOL isMetadataCurrent = [lastPayloadMetadata isEqualToDictionary:payloadMetadata];

    // generate messageId to scheduleId map for existing schedules
    NSMutableDictionary<NSString *, NSString *> *scheduleIDMap = [NSMutableDictionary dictionary];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [self.delegate getAllSchedules:^(NSArray<UASchedule *> *schedules) {
        for (UASchedule *schedule in schedules) {
            UAInAppMessage *message = (UAInAppMessage *)((UAInAppMessageScheduleInfo *)schedule.info).message;
            if (message.source != UAInAppMessageSourceRemoteData) {
                continue;
            }

            NSString *messageID = message.identifier;
            if (!messageID.length) {
                continue;
            }

            scheduleIDMap[messageID] = schedule.identifier;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    // cached messageId to scheduleId map is no longer used
    if ([self.dataStore dictionaryForKey:UAInAppMessagesScheduledMessagesKey]) {
        [self.dataStore removeObjectForKey:UAInAppMessagesScheduledMessagesKey];
    }

    // Skip if the payload timestamp is same as the last updated timestamp and metadata is current
    if ([payloadTimestamp isEqualToDate:lastPayloadTimestamp] && isMetadataCurrent) {
        return;
    }

    // Get the in-app message data, if it exists
    NSArray *messages;
    NSDictionary *messageData = messagePayload.data;
    if (!messageData || !messageData[UAInAppMessages] || ![messageData[UAInAppMessages] isKindOfClass:[NSArray class]]) {
        messages = @[];
    } else {
        messages = messageData[UAInAppMessages];
    }

    NSMutableArray<NSString *> *messageIDs = [NSMutableArray array];
    NSMutableArray<UAInAppMessageScheduleInfo *> *newSchedules = [NSMutableArray array];

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

        NSString *messageID = [UAInAppMessageScheduleInfo parseMessageID:message];
        if (!messageID.length) {
            UA_LERR("Missing in-app message ID: %@", message);
            continue;
        }

        [messageIDs addObject:messageID];

        // Ignore any messages that have not updated since the last payload
        if (isMetadataCurrent && [lastPayloadTimestamp compare:lastUpdatedTimeStamp] != NSOrderedAscending) {
            continue;
        }

        if ([createdTimeStamp compare:lastPayloadTimestamp] == NSOrderedDescending) {
            // New in-app message
            NSError *error;
            UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithJSON:message
                                                                                                 source:UAInAppMessageSourceRemoteData
                                                                                                  error:&error];
            if (!scheduleInfo || error) {
                UA_LERR(@"Failed to parse in-app message: %@ - %@", message, error);
                continue;
            }

            if ([self checkSchedule:scheduleInfo createdTimeStamp:createdTimeStamp]) {
                [newSchedules addObject:scheduleInfo];
            }
        } else if (scheduleIDMap[messageID]) {
            // Edit with new info and/or metadata
            __block NSError *error;

            UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithBuilderBlock:^(UAInAppMessageScheduleEditsBuilder *builder) {
                [builder applyFromJson:message source:UAInAppMessageSourceRemoteData error:&error];

                builder.metadata = [NSJSONSerialization stringWithObject:@{ UAInAppRemoteDataClientMetadataKey : payloadMetadata }];

                /* Since we cancel a schedule by setting the end time and start time to the payload's last modified timestamp,
                we need to reset them back if the edits do not update them*/
                if (!builder.end) {
                    builder.end = [NSDate distantFuture];
                }

                if (!builder.start) {
                    builder.start = [NSDate distantPast];
                }
            }];

            if (!edits || error) {
                UA_LERR(@"Failed to parse in-app message edits: %@ - %@", message, error);
                continue;
            }

            dispatch_group_enter(dispatchGroup);
            [self.delegate editScheduleWithID:scheduleIDMap[messageID]
                                                   edits:edits
                                       completionHandler:^(UASchedule *schedule) {
                dispatch_group_leave(dispatchGroup);
                if (schedule) {
                    UA_LTRACE("Updated in-app message: %@", messageID);
                }
            }];
        }
    }


    // End any messages that are no longer in the listing
    NSMutableArray<NSString *> *deletedMessageIDs = [NSMutableArray arrayWithArray:scheduleIDMap.allKeys];
    [deletedMessageIDs removeObjectsInArray:messageIDs];

    if (deletedMessageIDs.count) {
        /* To cancel, set the end time to the payload's last modified timestamp. To avoid validation errors,
         The start must be equal to or before the end time. If the schedule comes back, we will reset the start and end time
         from the schedule edits. */
        UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithBuilderBlock:^(UAInAppMessageScheduleEditsBuilder *builder) {
            builder.end = payloadTimestamp;
            builder.start = payloadTimestamp;
        }];

        for (NSString *messageID in deletedMessageIDs) {
            dispatch_group_enter(dispatchGroup);
            [self.delegate editScheduleWithID:scheduleIDMap[messageID]
                                                   edits:edits
                                       completionHandler:^(UASchedule *schedule) {
                dispatch_group_leave(dispatchGroup);
                if (schedule) {
                    UA_LTRACE("Ended in-app message: %@", messageID);
                }
            }];
        }
    }

    // New messages
    if (newSchedules.count) {
        dispatch_group_enter(dispatchGroup);

        [self.delegate scheduleMessagesWithScheduleInfo:newSchedules
                                               metadata:@{ UAInAppRemoteDataClientMetadataKey : payloadMetadata }
                                      completionHandler:^(NSArray<UASchedule *> *schedules) {
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

- (BOOL)checkSchedule:(UAInAppMessageScheduleInfo *)scheduleInfo createdTimeStamp:(NSDate *)createdTimeStamp {
    UAInAppMessageAudience *audience = scheduleInfo.message.audience;
    BOOL isNewUser = ([createdTimeStamp compare:self.scheduleNewUserCutOffTime] == NSOrderedAscending);
    return [UAInAppMessageAudienceChecks checkScheduleAudienceConditions:audience isNewUser:isNewUser];
}

- (NSDate *)scheduleNewUserCutOffTime {
    return [self.dataStore objectForKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

- (void)setScheduleNewUserCutOffTime:(NSDate *)time {
    [self.dataStore setObject:time forKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

- (BOOL)isRemoteSchedule:(UASchedule *)schedule {
    if (schedule.metadata[UAInAppRemoteDataClientMetadataKey]) {
        return YES;
    }

    // Legacy way of determining a remote-data schedule
    if ([schedule.info isKindOfClass:[UAInAppMessageScheduleInfo class]]) {
        UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
        if (info.message.source == UAInAppMessageSourceRemoteData) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)isScheduleUpToDate:(UASchedule *)schedule {
    if (!schedule.metadata) {
        return NO;
    }

    return [self.remoteDataProvider isMetadataCurrent:schedule.metadata[UAInAppRemoteDataClientMetadataKey]];
}

@end

