/* Copyright Urban Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UADisposable.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UAGlobal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAPush+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageScheduleEdits+Internal.h"
#import "UAScheduleEdits+Internal.h"

NSString * const UAInAppMessages = @"in_app_messages";
NSString * const UAInAppMessagesCreatedJSONKey = @"created";
NSString * const UAInAppMessagesUpdatedJSONKey = @"last_updated";

@interface UAInAppRemoteDataClient()
@property (nonatomic,strong) UAInAppMessageManager *inAppMessageManager;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UADisposable *remoteDataSubscription;
@property (nonatomic, copy) NSDictionary *scheduleIDMap;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation UAInAppRemoteDataClient

NSString * const UAInAppMessagesLastPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
NSString * const UAInAppMessagesScheduledMessagesKey = @"UAInAppRemoteDataClient.ScheduledMessages";
NSString * const UAInAppMessagesScheduledNewUserCutoffTimeKey = @"UAInAppRemoteDataClient.ScheduledNewUserCutoffTime";

- (instancetype)initWithScheduler:(UAInAppMessageManager *)scheduler
                remoteDataManager:(UARemoteDataManager *)remoteDataManager
                        dataStore:(UAPreferenceDataStore *)dataStore
                             push:(UAPush *)push {
    
    self = [super init];
    
    if (self) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;

        self.inAppMessageManager = scheduler;
        self.dataStore = dataStore;
        UA_WEAKIFY(self);
        self.remoteDataSubscription = [remoteDataManager subscribeWithTypes:@[UAInAppMessages]
                                                                      block:^(NSArray<UARemoteDataPayload *> * _Nonnull messagePayloads) {
                                                                          UA_STRONGIFY(self);
                                                                          [self.operationQueue addOperationWithBlock:^{
                                                                              UA_STRONGIFY(self);
                                                                              [self processInAppMessageData:[messagePayloads firstObject]];
                                                                          }];
                                                                      }];
        if (!self.scheduleNewUserCutOffTime) {
            self.scheduleNewUserCutOffTime = (push.channelID) ? [NSDate distantPast] : [NSDate date];
        }
    }

    return self;
}

+ (instancetype)clientWithScheduler:(UAInAppMessageManager *)scheduler
                  remoteDataManager:(UARemoteDataManager *)remoteDataManager
                          dataStore:(UAPreferenceDataStore *)dataStore
                               push:(UAPush *)push {
    return [[UAInAppRemoteDataClient alloc] initWithScheduler:scheduler
                                            remoteDataManager:remoteDataManager
                                                    dataStore:dataStore
                                                         push:push];
}

- (void)dealloc {
    [self.remoteDataSubscription dispose];
}

- (void)processInAppMessageData:(UARemoteDataPayload *)messagePayload {
    NSDate *thisPayloadTimeStamp = messagePayload.timestamp;
    NSDate *lastUpdate = [self.dataStore objectForKey:UAInAppMessagesLastPayloadTimeStampKey] ?: [NSDate distantPast];

    // Skip if the payload timestamp is same as the last updated timestamp
    if ([thisPayloadTimeStamp isEqualToDate:lastUpdate]) {
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

    __block NSMutableDictionary *scheduleIDMap = [NSMutableDictionary dictionaryWithDictionary:self.scheduleIDMap];
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
        if ([lastUpdate compare:lastUpdatedTimeStamp] != NSOrderedAscending) {
            continue;
        }

        // If we do not have a schedule ID for the message ID, try to look it up first
        if (!scheduleIDMap[messageID]) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [self.inAppMessageManager getSchedulesWithMessageID:messageID completionHandler:^(NSArray<UASchedule *> *schedules) {
                dispatch_semaphore_signal(semaphore);

                // Make sure we only have a single schedule for the message ID
                if (schedules.count == 1) {
                    scheduleIDMap[messageID] = schedules[0].identifier;
                }
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }

        if ([createdTimeStamp compare:lastUpdate] == NSOrderedDescending) {
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
            // Update
            __block NSError *error;

            UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithBuilderBlock:^(UAInAppMessageScheduleEditsBuilder *builder) {
                [builder applyFromJson:message error:&error];

                // Since we cancel a schedule by setting the end time to the distant past, we need to reset it back to distant future
                // if the edits/schedule does not define an end time.
                if (!builder.end) {
                    builder.end = [NSDate distantFuture];
                }
            }];

            if (!edits || error) {
                UA_LERR(@"Failed to parse in-app message edits: %@ - %@", message, error);
                continue;
            }

            dispatch_group_enter(dispatchGroup);
            [self.inAppMessageManager editScheduleWithID:scheduleIDMap[messageID]
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
        // To cancel, we need to set the end time to distant past. To avoid validation error where
        // start needs to be equal or before the end time, we also need to set the start.
        // If the schedule comes back, the edits will reapply the start time from the schedule
        // if it is set.
        UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithBuilderBlock:^(UAInAppMessageScheduleEditsBuilder *builder) {
            builder.end = [NSDate distantPast];
            builder.start = [NSDate distantPast];
        }];

        for (NSString *messageID in deletedMessageIDs) {
            dispatch_group_enter(dispatchGroup);
            [self.inAppMessageManager editScheduleWithID:scheduleIDMap[messageID]
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

        [self.inAppMessageManager scheduleMessagesWithScheduleInfo:newSchedules completionHandler:^(NSArray<UASchedule *> *schedules) {
            for (UASchedule *schedule in schedules) {
                if (!schedule) {
                    continue;
                }
                UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
                UA_LTRACE(@"Scheduled new in-app messages: %@", info.message.identifier);
                scheduleIDMap[info.message.identifier] = schedule.identifier;
            }

            dispatch_group_leave(dispatchGroup);
        }];
    }

    // Wait for everything to finish
    dispatch_group_wait(dispatchGroup,  DISPATCH_TIME_FOREVER);

    // Save state
    self.scheduleIDMap = scheduleIDMap;
    [self.dataStore setObject:thisPayloadTimeStamp forKey:UAInAppMessagesLastPayloadTimeStampKey];
}

- (BOOL)checkSchedule:(UAInAppMessageScheduleInfo *)scheduleInfo createdTimeStamp:(NSDate *)createdTimeStamp {
    UAInAppMessageAudience *audience = scheduleInfo.message.audience;
    BOOL isNewUser = ([createdTimeStamp compare:self.scheduleNewUserCutOffTime] == NSOrderedAscending);
    return [UAInAppMessageAudienceChecks checkScheduleAudienceConditions:audience isNewUser:isNewUser];
}

- (void)setScheduleIDMap:(NSDictionary *)scheduleIDMap {
    [self.dataStore setObject:scheduleIDMap forKey:UAInAppMessagesScheduledMessagesKey];
}

- (NSDictionary *)scheduleIDMap {
    return [self.dataStore dictionaryForKey:UAInAppMessagesScheduledMessagesKey];
}

- (NSDate *)scheduleNewUserCutOffTime {
    return [self.dataStore objectForKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

- (void)setScheduleNewUserCutOffTime:(NSDate *)time {
    [self.dataStore setObject:time forKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

@end
