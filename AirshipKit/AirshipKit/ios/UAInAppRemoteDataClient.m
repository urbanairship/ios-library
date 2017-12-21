/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UADisposable.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils.h"
#import "UAGlobal.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAPush+Internal.h"

NSString * const UAInAppMessages = @"in_app_messages";
NSString * const UAInAppMessagesCreatedJSONKey = @"created";
NSString * const UAInAppMessagesUpdatedJSONKey = @"last_updated";

@interface UAInAppRemoteDataClient()
/**
 * The in app message scheduler.
 */
@property (nonatomic,strong) UAInAppMessageManager *inAppMessageScheduler;

/**
 * The SDK preferences data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The subscription for remote data.
 */
@property (nonatomic, strong) UADisposable *remoteDataSubscription;

@end

@implementation UAInAppRemoteDataClient

NSString * const UAInAppMessagesLastPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
NSString * const UAInAppMessagesScheduledMessagesKey = @"UAInAppRemoteDataClient.ScheduledMessages";
NSString * const UAInAppMessagesScheduledNewUserCutoffTimeKey = @"UAInAppRemoteDataClient.ScheduledNewUserCutoffTime";

- (instancetype)initWithScheduler:(UAInAppMessageManager *)scheduler
                remoteDataManager:(UARemoteDataManager *)remoteDataManager
                        dataStore:(UAPreferenceDataStore *)dataStore
                             push:(UAPush *)push {
    
    self = [self init];
    if (self) {
        self.inAppMessageScheduler = scheduler;
        self.dataStore = dataStore;
        UA_WEAKIFY(self);
        self.remoteDataSubscription = [remoteDataManager subscribeWithTypes:@[UAInAppMessages]
                                                                      block:^(NSArray<UARemoteDataPayload *> * _Nonnull messagePayloads) {
                                                                          UA_STRONGIFY(self);
                                                                          // get the array of messages from the remote data
                                                                          if (messagePayloads.count) {
                                                                              UARemoteDataPayload *messagePayload = messagePayloads[0];
                                                                              if (![messagePayload.type isEqualToString:UAInAppMessages]) {
                                                                                  return;
                                                                              }
                                                                              
                                                                              [self processInAppMessageData:messagePayload];
                                                                          }
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
    // get the in-app message data, if it exists
    NSArray *messages;
    NSDictionary *messageData = messagePayload.data;
    if (!messageData || !messageData[UAInAppMessages] || ![messageData[UAInAppMessages] isKindOfClass:[NSArray class]]) {
        messages = @[];
    } else {
        messages = messageData[UAInAppMessages];
    }

    // get the payload's last modified timestamp
    NSDate *thisPayloadTimeStamp = messagePayload.timestamp;
    
    // get last updated time and current in-app message ids from the datastore
    NSDate *lastUpdate = [self.dataStore objectForKey:UAInAppMessagesLastPayloadTimeStampKey] ?: [NSDate distantPast];
    
    // skip if payload timestamp hasn't changed
    if ([thisPayloadTimeStamp isEqualToDate:lastUpdate]) {
        return;
    }
    
    NSArray<NSString *> *currentMessageIDs = [[self getScheduledMessageIDs] copy];
    
    NSMutableArray<NSString *> *messageIDs = [NSMutableArray array];
    NSMutableArray<UAInAppMessageScheduleInfo *> *newSchedules = [NSMutableArray array];
    
    // validate messages and create new schedules
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
        
        if ([createdTimeStamp compare:lastUpdate] == NSOrderedDescending) {
            // this is a new message
            if ([currentMessageIDs containsObject:messageID]) {
                // it's an error if there are already schedules for this message - skip
                continue;
            }
            NSError *error;
            UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo inAppMessageScheduleInfoWithJSON:message error:&error];
            if (!scheduleInfo || error) {
                UA_LERR(@"Failed to parse in-app message: %@ - %@", message, error);
                continue;
            }
            NSDate *createdTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesCreatedJSONKey]];
            if ([self checkSchedule:scheduleInfo createdTimeStamp:createdTimeStamp]) {
                [newSchedules addObject:scheduleInfo];
            }
        } else if (lastUpdatedTimeStamp > lastUpdate) {
            // TODO: updates - Implement equivalent to Android SDK
        }
    }
    
    // get list of deleted messages which are messages that arrived in an earlier remote data, but no longer exist
    NSMutableArray<NSString *> *deletedMessageIDs = [NSMutableArray arrayWithArray:[self getScheduledMessageIDs]];
    [deletedMessageIDs removeObjectsInArray:messageIDs];
    
    // cancel deleted messages
    if (deletedMessageIDs.count) {
        [self.inAppMessageScheduler cancelMessagesWithIDs:deletedMessageIDs];
    }
    
    // schedule new messages, and save all remaining message ids and the payload time stamp
    if (newSchedules.count) {
        UA_WEAKIFY(self);
        [self.inAppMessageScheduler scheduleMessagesWithScheduleInfo:newSchedules completionHandler:^(void) {
            UA_STRONGIFY(self);
            [self setScheduledMessageIDs:messageIDs];
            [self.dataStore setObject:thisPayloadTimeStamp forKey:UAInAppMessagesLastPayloadTimeStampKey];
        }];
    } else {
        [self setScheduledMessageIDs:messageIDs];
        [self.dataStore setObject:thisPayloadTimeStamp forKey:UAInAppMessagesLastPayloadTimeStampKey];
   }
}

- (BOOL)checkSchedule:(UAInAppMessageScheduleInfo *)scheduleInfo createdTimeStamp:(NSDate *)createdTimeStamp {
    UAInAppMessageAudience *audience = scheduleInfo.message.audience;
    BOOL isNewUser = ([createdTimeStamp compare:self.scheduleNewUserCutOffTime] == NSOrderedAscending);
    return [UAInAppMessageAudienceChecks checkAudience:audience isNewUser:isNewUser];
}

/**
 * Gets the stored scheduled message IDs.
 *
 * @return The list of scheduled message IDs.
 */
- (NSArray<NSString *> *)getScheduledMessageIDs {
    NSArray<NSString *> *scheduledMessageIDs = [self.dataStore arrayForKey:UAInAppMessagesScheduledMessagesKey];
    if (!scheduledMessageIDs) {
        scheduledMessageIDs = [NSArray array];
    }
    
    return scheduledMessageIDs;
}

/**
 * Sets the stored scheduled message IDs.
 *
 * @param messageIDs The list of scheduled message IDs.
 */
- (void)setScheduledMessageIDs:(NSArray<NSString *> *)messageIDs {
    [self.dataStore setObject:messageIDs forKey:UAInAppMessagesScheduledMessagesKey];
}

/**
 * Gets the stored schedule new user cut off time.
 *
 * @return The new user cut off time.
 */
- (NSDate *)scheduleNewUserCutOffTime {
    return [self.dataStore objectForKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

/**
 * Sets the schedule new user cut off time. Any schedules that have
 * a new user condition will be dropped if the schedule create time is after the
 * cut off time.
 *
 * @param time The schedule new user cut off time.
 */- (void)setScheduleNewUserCutOffTime:(NSDate *)time {
    [self.dataStore setObject:time forKey:UAInAppMessagesScheduledNewUserCutoffTimeKey];
}

@end
