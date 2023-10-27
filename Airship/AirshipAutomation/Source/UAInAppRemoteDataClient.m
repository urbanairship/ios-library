/* Copyright Airship and Contributors */

#import "UAInAppRemoteDataClient+Internal.h"
#import "UASchedule+Internal.h"
#import "UAInAppMessageSchedule.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessage+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "NSDictionary+UAAdditions+Internal.h"
#import "UAActionSchedule.h"
#import "UADeferredSchedule+Internal.h"
#import "NSObject+UAAdditions+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


// app
static NSString * const UAInAppMessagesLastAppPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp";
static NSString * const UAInAppMessagesLastAppPayloadInfoKey = @"UAInAppRemoteDataClient.LastRemoteDataInfo";
static NSString * const UAInAppMessagesLastAppSDKVersionKey = @"UAInAppRemoteDataClient.LastSDKVersion";

// Old
static NSString * const UAInAppMessagesLastPayloadMetadataKey = @"UAInAppRemoteDataClient.LastPayloadMetadata";


// contact
static NSString * const UAInAppMessagesLastContactPayloadTimeStampKey = @"UAInAppRemoteDataClient.LastPayloadTimeStamp.Contact";
static NSString * const UAInAppMessagesLastContactPayloadInfoKey = @"UAInAppRemoteDataClient.LasteRemoteDataInfo.Contact";
static NSString * const UAInAppMessagesLastContactSDKVersionKey = @"UAInAppRemoteDataClient.LastSDKVersion.Contact";


static NSString * const UAInAppRemoteDataClientMetadataKey = @"com.urbanairship.iaa.REMOTE_DATA_METADATA";
static NSString * const UAInAppRemoteDataClientInfoKey = @"com.urbanairship.iaa.REMOTE_DATA_INFO";

static NSString * const UAFrequencyConstraintsKey = @"frequency_constraints";
static NSString * const UAFrequencyConstraintPeriodKey = @"period";
static NSString * const UAFrequencyConstraintBoundaryKey = @"boundary";
static NSString * const UAFrequencyConstraintRangeKey = @"range";
static NSString * const UAFrequencyConstraintIDKey = @"id";

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
static NSString *const UAScheduleInfoTriggeredTimeKey = @"triggered_time";

static NSString *const UAScheduleInfoTypeActions = @"actions";
static NSString *const UAScheduleInfoTypeDeferred = @"deferred";
static NSString *const UAScheduleInfoTypeInAppMessage = @"in_app_message";

static NSString *const UAScheduleInfoInAppMessageKey = @"message";
static NSString *const UAScheduleInfoActionsKey = @"actions";
static NSString *const UAScheduleInfoDeferredKey = @"deferred";

static NSString *const UAScheduleInfoCampaignsKey = @"campaigns";
static NSString *const UAScheduleInfoReportingContextKey = @"reporting_context";

static NSString *const UAScheduleInfoFrequencyConstraintIDsKey = @"frequency_constraint_ids";

static NSString *const UAScheduleInfoMessageTypeKey = @"message_type";
static NSString *const UAScheduleInfoBypassHoldoutGroupsKey = @"bypass_holdout_groups";
static NSString *const UAScheduleInfoProducId = @"product_id";

@interface UAInAppRemoteDataClient()
@property(nonatomic, strong) UAInAppMessageManager *inAppMessageManager;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(atomic, strong) UADisposable *remoteDataSubscription;
@property(nonatomic, strong) UADispatcher *schedulerDispatcher;
@property(nonatomic, strong) UAInAppCoreSwiftBridge *inAppCoreSwiftBridge;
@property(nonatomic, copy) NSDate *scheduleNewUserCutOffTime;
@property(nonatomic, copy) NSDictionary *lastPayloadMetadata;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, copy) NSString *SDKVersion;

@end

@implementation UAInAppRemoteDataClient



- (instancetype)initWithInAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                         dataStore:(UAPreferenceDataStore *)dataStore
                           channel:(UAChannel *)channel
               schedulerDispatcher:(UADispatcher *)schedulerDispatcher
                        SDKVersion:(NSString *)SDKVersion {

    self = [super init];

    if (self) {
        self.schedulerDispatcher = schedulerDispatcher;
        self.inAppCoreSwiftBridge = inAppCoreSwiftBridge;
        self.dataStore = dataStore;
        self.channel = channel;
        self.SDKVersion = SDKVersion;
    }

    return self;
}

+ (instancetype)clientWithInAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel {


    return [[UAInAppRemoteDataClient alloc] initWithInAppCoreSwiftBridge:inAppCoreSwiftBridge
                                                     dataStore:dataStore
                                                       channel:channel
                                           schedulerDispatcher:[UADispatcher serialUtility]
                                                    SDKVersion:[UAirshipVersion get]];
}



+ (instancetype)clientWithInAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                                     dataStore:(UAPreferenceDataStore *)dataStore
                                       channel:(UAChannel *)channel
                           schedulerDispatcher:(UADispatcher *)schedulerDispatcher
                                    SDKVersion:(NSString *)SDKVersion {

    return [[UAInAppRemoteDataClient alloc] initWithInAppCoreSwiftBridge:inAppCoreSwiftBridge
                                                     dataStore:dataStore
                                                       channel:channel
                                           schedulerDispatcher:schedulerDispatcher
                                                   SDKVersion:SDKVersion];
}

- (void)subscribe {
    @synchronized (self) {
        if (self.remoteDataSubscription != nil) {
            return;
        }

        UA_WEAKIFY(self);
        self.remoteDataSubscription = [self.inAppCoreSwiftBridge subscribeWithTypes:@[UAInAppMessages]
                                                                    block:^(NSArray<UARemoteDataPayload *> * _Nonnull messagePayloads) {
            UA_STRONGIFY(self);
            [self.schedulerDispatcher dispatchAsync:^{
                UA_STRONGIFY(self);
                [self onReceiveRemoteData:messagePayloads];
            }];
        }];
    }
}

- (void)unsubscribe {
    @synchronized (self) {
        [self.remoteDataSubscription dispose];
        self.remoteDataSubscription = nil;
    }
}

- (void)dealloc {
    [self unsubscribe];
}

- (UARemoteDataPayload *)firstPayloadWithArray:(NSArray<UARemoteDataPayload *> *)payloads withSource:(UARemoteDataSource)source {
    for (UARemoteDataPayload *payload in payloads) {
        if (payload.remoteDataInfo.source == source) {
            return payload;
        }
    }

    return nil;
}

- (void)onReceiveRemoteData:(NSArray<UARemoteDataPayload *> *)payloads {
    // Fixes issue with 17.x -> 16.x -> 17.x
    if ([self.dataStore objectForKey:UAInAppMessagesLastPayloadMetadataKey]) {
        [self.dataStore removeObjectForKey:UAInAppMessagesLastContactPayloadInfoKey];
        [self.dataStore removeObjectForKey:UAInAppMessagesLastAppPayloadInfoKey];
        [self.dataStore removeObjectForKey:UAInAppMessagesLastPayloadMetadataKey];
    }

    [self processAppRemoteData:[self firstPayloadWithArray:payloads withSource:UARemoteDataSourceApp]];
    [self processContactRemoteData:[self firstPayloadWithArray:payloads withSource:UARemoteDataSourceContact]];
}

- (void)processContactRemoteData:(UARemoteDataPayload *)messagePayload {
    if (!messagePayload) {
        // If we have data, stop all IAA and delete the keys
        if ([self.dataStore objectForKey:UAInAppMessagesLastContactPayloadInfoKey]) {
            [self stopAllForSource:UARemoteDataSourceContact];
            [self.dataStore removeObjectForKey:UAInAppMessagesLastContactPayloadInfoKey];
        }
        return;
    }

    // We store the last update and the last SDK version with the contact ID in the key so we can
    // probably detect new schedules across contact ID changes. We continue to store the last payload
    // info without the contact Id so we can detect when we should process the listing again
    NSString *contactID = (messagePayload.remoteDataInfo.contactID) ?: @"";
    NSString *lastPayloadTimestampKey = [UAInAppMessagesLastContactPayloadTimeStampKey stringByAppendingString:contactID];
    NSString *lastSDKVersionKey = [UAInAppMessagesLastContactSDKVersionKey stringByAppendingString:contactID];

    NSDate *lastPayloadTimestamp = [self.dataStore objectForKey:lastPayloadTimestampKey] ?: [NSDate distantPast];
    NSString *lastSDKVersion = [self.dataStore stringForKey:lastSDKVersionKey];

    NSString *lastRemoteInfoString = [self.dataStore stringForKey:UAInAppMessagesLastContactPayloadInfoKey] ?: @"";
    UARemoteDataInfo *lastRemoteInfo = [UARemoteDataInfo fromJSONWithString:lastRemoteInfoString error:nil];

    BOOL processed = [self processRemoteData:messagePayload
                                      source:UARemoteDataSourceContact
                        lastPayloadTimestamp:lastPayloadTimestamp
                              lastRemoteInfo:lastRemoteInfo
                              lastSDKVersion:lastSDKVersion];

    // Save state
    if (processed) {
        [self.dataStore setObject:[messagePayload.remoteDataInfo toEncodedJSONStringAndReturnError:nil]
                           forKey:UAInAppMessagesLastContactPayloadInfoKey];
        [self.dataStore setObject:messagePayload.timestamp forKey:lastPayloadTimestampKey];
        [self.dataStore setObject:self.SDKVersion forKey:lastSDKVersionKey];
    }
}

- (void)processAppRemoteData:(UARemoteDataPayload *)messagePayload {
    if (!messagePayload) {
        // If we have data, stop all IAA and delete the keys
        if ([self.dataStore objectForKey:UAInAppMessagesLastAppPayloadInfoKey]) {
            [self stopAllForSource:UARemoteDataSourceApp];
            [self.dataStore removeObjectForKey:UAInAppMessagesLastAppPayloadInfoKey];
        }
        return;
    }

    // Load state
    NSDate *lastPayloadTimestamp = [self.dataStore objectForKey:UAInAppMessagesLastAppPayloadTimeStampKey] ?: [NSDate distantPast];
    NSString *lastSDKVersion = [self.dataStore stringForKey:UAInAppMessagesLastAppSDKVersionKey];
    NSString *lastRemoteInfoString = [self.dataStore stringForKey:UAInAppMessagesLastAppPayloadInfoKey] ?: @"";
    UARemoteDataInfo *lastRemoteInfo = [UARemoteDataInfo fromJSONWithString:lastRemoteInfoString error:nil];

    BOOL processed = [self processRemoteData:messagePayload
                                      source:UARemoteDataSourceApp
                        lastPayloadTimestamp:lastPayloadTimestamp
                              lastRemoteInfo:lastRemoteInfo
                              lastSDKVersion:lastSDKVersion];

    // Save state
    if (processed) {
        [self.dataStore setObject:[messagePayload.remoteDataInfo toEncodedJSONStringAndReturnError:nil] forKey:UAInAppMessagesLastAppPayloadInfoKey];
        [self.dataStore setObject:messagePayload.timestamp forKey:UAInAppMessagesLastAppPayloadTimeStampKey];
        [self.dataStore setObject:self.SDKVersion forKey:UAInAppMessagesLastAppSDKVersionKey];
    }
}

- (BOOL)processRemoteData:(UARemoteDataPayload *)messagePayload
                   source:(UARemoteDataSource)source
     lastPayloadTimestamp:(NSDate *) lastPayloadTimestamp
           lastRemoteInfo:(UARemoteDataInfo *)lastRemoteInfo
           lastSDKVersion:(NSString *)lastSDKVersion {

    NSDate *payloadTimestamp = messagePayload.timestamp;
    UARemoteDataInfo *payloadInfo = messagePayload.remoteDataInfo;

    NSDictionary *scheduleMetadata = @{
        UAInAppRemoteDataClientMetadataKey: @{},
        UAInAppRemoteDataClientInfoKey: [payloadInfo toEncodedJSONStringAndReturnError:nil] ?: @{}
    };

    BOOL isMetadataCurrent = [lastRemoteInfo isEqual:messagePayload.remoteDataInfo];

    // Skip if the payload timestamp is same as the last updated timestamp and metadata is current
    if ([payloadTimestamp isEqualToDate:lastPayloadTimestamp] && isMetadataCurrent) {
        return NO;
    }
    
    NSArray *messageJSONList = [messagePayload.data arrayForKey:UAInAppMessages defaultValue:@[]];
    NSArray *constraintJSONList = [messagePayload.data arrayForKey:UAFrequencyConstraintsKey defaultValue:@[]];

    NSArray<NSString *> *currentScheduleIDs = [self getCurrentRemoteScheduleIDForSource:source];
    NSMutableArray<NSString *> *scheduleIDs = [NSMutableArray array];
    NSMutableArray<UASchedule *> *newSchedules = [NSMutableArray array];

    NSMutableArray *constraints = [NSMutableArray array];
    for (id constraintJSON in constraintJSONList) {
        UAFrequencyConstraint *constraint = [UAInAppRemoteDataClient parseConstraintWithJSON:constraintJSON];
        if (constraint) {
            [constraints addObject:constraint];
        }
    }
    [self.delegate updateConstraints:constraints];

    // Dispatch group
    dispatch_group_t dispatchGroup = dispatch_group_create();

    // Validate messages and create new schedules
    for (NSDictionary *message in messageJSONList) {
        NSDate *createdTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesCreatedJSONKey]];
        NSDate *lastUpdatedTimeStamp = [UAUtils parseISO8601DateFromString:message[UAInAppMessagesUpdatedJSONKey]];

        if (!createdTimeStamp || !lastUpdatedTimeStamp) {
            UA_LERR(@"Failed to parse in-app message timestamps: %@", message);
            continue;
        }

        NSString *scheduleID = [UAInAppRemoteDataClient parseScheduleID:message];
        if (!scheduleID.length) {
            UA_LERR(@"Missing ID: %@", message);
            continue;
        }

        [scheduleIDs addObject:scheduleID];

        // Ignore any messages that have not updated since the last payload
        if (isMetadataCurrent && [lastPayloadTimestamp compare:lastUpdatedTimeStamp] != NSOrderedAscending) {
            continue;
        }

        if ([currentScheduleIDs containsObject:scheduleID]) {
            UAScheduleEdits *edits = [UAInAppRemoteDataClient parseScheduleEditsWithJSON:message
                                                                                metadata:scheduleMetadata
                                                                   newUserEvaluationDate:createdTimeStamp];

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
                    UA_LTRACE(@"Updated in-app automation: %@", scheduleID);
                }
            }];
        } else if ([self isNewSchedule:message
                      createdTimeStamp:createdTimeStamp
                  lastPayloadTimeStamp:lastPayloadTimestamp
                        lastSDKVersion:lastSDKVersion]) {

            // New in-app message
            UASchedule *schedule = [UAInAppRemoteDataClient parseScheduleWithJSON:message
                                                                         metadata:scheduleMetadata
                                                            newUserEvaluationDate:createdTimeStamp];
            if (!schedule) {
                UA_LERR(@"Failed to parse in-app automation: %@", message);
                continue;
            }

            [newSchedules addObject:schedule];
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
                    UA_LTRACE(@"Ended in-app automation: %@", scheduleID);
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
    return YES;
}


- (void)stopAllForSource:(UARemoteDataSource)source {
    // Dispatch group
    dispatch_group_t dispatchGroup = dispatch_group_create();
    NSArray<NSString *> *scheduleIDs = [self getCurrentRemoteScheduleIDForSource:source];

    NSDate *date = [NSDate date];
    if (scheduleIDs.count) {
        /* To cancel, set the end time to the payload's to now. To avoid validation errors,
         The start must be equal to or before the end time. If the schedule comes back, we will reset the start and end time
         from the schedule edits. */
        UAScheduleEdits *edits = [UAScheduleEdits editsWithBuilderBlock:^(UAScheduleEditsBuilder * _Nonnull builder) {
            builder.end = date;
            builder.start = date;
        }];

        for (NSString *scheduleID in scheduleIDs) {
            dispatch_group_enter(dispatchGroup);
            [self.delegate editScheduleWithID:scheduleID
                                        edits:edits
                            completionHandler:^(BOOL result) {
                dispatch_group_leave(dispatchGroup);
                if (result) {
                    UA_LTRACE(@"Ended in-app automation: %@", scheduleID);
                }
            }];
        }
    }
    // Wait for everything to finish
    dispatch_group_wait(dispatchGroup,  DISPATCH_TIME_FOREVER);
}

- (BOOL)isNewSchedule:(NSDictionary *)messageJSON
     createdTimeStamp:(NSDate *)createdTimeStamp
 lastPayloadTimeStamp:(NSDate *)lastPayloadTimeStamp
       lastSDKVersion:(NSString *)lastSDKVersion {
    
    if ([createdTimeStamp compare:lastPayloadTimeStamp] == NSOrderedDescending) {
        return YES;
    }
    
    NSString *minSDKVersion = messageJSON[@"min_sdk_version"];
    if (!minSDKVersion.length) {
        return NO;
    }
    
    // We can skip checking if the min_sdk_version is newer than the current SDK version since
    // remote-data will filter them out. This flag is only a hint to the SDK to treat a schedule with
    // an older created timestamp as a new schedule.
    
    NSString *constraint;
    if (!lastSDKVersion.length) {
        // If we do not have a last SDK version, then we are coming from an SDK older than
        // 16.2.0. Check for a min SDK version newer or equal to 16.2.0.
        constraint = @"[16.2.0,)";
    } else {
        // Check that the min SDK is newer than the last SDK version
        constraint = [NSString stringWithFormat:@"]%@,)", lastSDKVersion];
    }
    
    UAVersionMatcher *matcher = [UAVersionMatcher matcherWithVersionConstraint:constraint];
    return [matcher evaluateObject:minSDKVersion];
}

- (NSArray<NSString *> *)getCurrentRemoteScheduleIDForSource:(UARemoteDataSource)source {
    NSMutableArray *currentScheduleIDs = [NSMutableArray array];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    UA_WEAKIFY(self)
    [self.delegate getSchedules:^(NSArray<UASchedule *> *schedules) {
        UA_STRONGIFY(self)
        for (UASchedule *schedule in schedules) {
            if (![self isRemoteSchedule:schedule]) {
                continue;
            }

            UARemoteDataInfo *info = [self remoteDataInfoFromSchedule:schedule];
            if ((!info && source == UARemoteDataSourceApp) || info.source == source) {
                [currentScheduleIDs addObject:schedule.identifier];
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return currentScheduleIDs;
}

- (BOOL)isRemoteSchedule:(UASchedule *)schedule {
    if (schedule.metadata[UAInAppRemoteDataClientMetadataKey] || schedule.metadata[UAInAppRemoteDataClientInfoKey]) {
        return YES;
    }

    // Legacy way of determining a remote-data schedule
    if (schedule.type == UAScheduleTypeInAppMessage) {
        UAInAppMessage *message = (UAInAppMessage *)schedule.data;
        return message.source == UAInAppMessageSourceRemoteData;
    }

    return NO;
}


- (void)isScheduleUpToDate:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    if (![self isRemoteSchedule:schedule]) {
        completionHandler(YES);
        return;
    }

    UARemoteDataInfo *remoteDataInfo = [self remoteDataInfoFromSchedule:schedule];
    [self.inAppCoreSwiftBridge isCurrentWithRemoteDataInfo:remoteDataInfo
                               completionHandler:completionHandler];
}


- (void)scheduleRequiresRefresh:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    if (![self isRemoteSchedule:schedule]) {
        completionHandler(NO);
        return;
    }

    UARemoteDataInfo *remoteDataInfo = [self remoteDataInfoFromSchedule:schedule];
    [self.inAppCoreSwiftBridge requiresUpdateWithRemoteDataInfo:remoteDataInfo completionHandler:completionHandler];
}

- (void)waitFullRefresh:(UASchedule *)schedule completionHandler:(void (^)(void))completionHandler {
    if (![self isRemoteSchedule:schedule]) {
        completionHandler();
        return;
    }

    UARemoteDataInfo *remoteDataInfo = [self remoteDataInfoFromSchedule:schedule];
    [self.inAppCoreSwiftBridge waitFullRefreshWithRemoteDataInfo:remoteDataInfo completionHandler:^{
        [self.schedulerDispatcher dispatchAsync:^{
            completionHandler();
        }];
    }];
}

- (void)bestEffortRefresh:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler {
    if (![self isRemoteSchedule:schedule]) {
        completionHandler(YES);
        return;
    }
    
    UARemoteDataInfo *remoteDataInfo = [self remoteDataInfoFromSchedule:schedule];
    [self.inAppCoreSwiftBridge bestEffortRefreshWithRemoteDataInfo:remoteDataInfo completionHandler:^(BOOL result) {
        [self.schedulerDispatcher dispatchAsync:^{
            completionHandler(result);
        }];
    }];
}

- (void)notifyOutdatedSchedule:(UASchedule *)schedule completionHandler:(void (^)(void))completionHandler {
    if (![self isRemoteSchedule:schedule]) {
        completionHandler();
        return;
    }

    UARemoteDataInfo *remoteDataInfo = [self remoteDataInfoFromSchedule:schedule];
    [self.inAppCoreSwiftBridge notifyOutdatedWithRemoteDataInfo:remoteDataInfo completionHandler:completionHandler];
}

- (UARemoteDataInfo *)remoteDataInfoFromSchedule:(UASchedule *)schedule {
    if (![self isRemoteSchedule:schedule]) {
        return nil;
    }

    if (!schedule.metadata) {
        return nil;
    }

    id remoteDataInfo = schedule.metadata[UAInAppRemoteDataClientInfoKey];
    if (!remoteDataInfo) {
        return nil;
    }

    if ([remoteDataInfo isKindOfClass:[NSString class]]) {
        return [UARemoteDataInfo fromJSONWithString:remoteDataInfo error:nil];
    }

    return nil;
}

+ (UAFrequencyConstraint *)parseConstraintWithJSON:(id)JSON {
    NSString *ID = [JSON stringForKey:UAFrequencyConstraintIDKey defaultValue:nil];
    NSNumber *range = [JSON numberForKey:UAFrequencyConstraintRangeKey defaultValue:nil];
    NSNumber *boundary = [JSON numberForKey:UAFrequencyConstraintBoundaryKey defaultValue:nil];
    NSString *period = [JSON stringForKey:UAFrequencyConstraintPeriodKey defaultValue:nil];

    if (!ID || !range || !boundary || !period) {
        UA_LERR(@"Invalid constraint: %@", JSON);
        return nil;
    }

    NSTimeInterval rangeInSeconds = [range doubleValue];
    if ([period isEqual:@"seconds"]) {
        rangeInSeconds = [range doubleValue];
    } else if ([period isEqual:@"minutes"]) {
        rangeInSeconds = [range doubleValue] * 60;
    } else if ([period isEqual:@"hours"]) {
        rangeInSeconds = [range doubleValue] * 60 * 60;
    } else if ([period isEqual:@"days"]) {
        rangeInSeconds = [range doubleValue] * 60 * 60 * 24;
    } else if ([period isEqual:@"weeks"]) {
        rangeInSeconds = [range doubleValue] * 60 * 60 * 24 * 7;
    } else if ([period isEqual:@"months"]) {
        rangeInSeconds = [range doubleValue] * 60 * 60 * 24 * 30;
    } else if ([period isEqual:@"years"]) {
        rangeInSeconds = [range doubleValue] * 60 * 60 * 24 * 365;
    } else {
        UA_LERR(@"Invalid period %@ in constraint: %@", period, JSON);
        return nil;
    }

    return [UAFrequencyConstraint frequencyConstraintWithIdentifier:ID range:rangeInSeconds count:[boundary unsignedIntegerValue]];
}

+ (UASchedule *)parseScheduleWithJSON:(id)JSON
                             metadata:(NSDictionary *)metadata
                newUserEvaluationDate:(NSDate *)newUserEvaluationDate {
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


    return [UAInAppRemoteDataClient scheduleWithJSON:JSON builderBlock:^(UAScheduleBuilder *builder) {
        builder.identifier = [UAInAppRemoteDataClient parseScheduleID:JSON];
        builder.metadata = metadata;
        builder.triggers = triggers;
        builder.delay = delay;
        builder.group = [JSON stringForKey:UAScheduleInfoGroupKey defaultValue:nil];
        builder.limit = [[JSON numberForKey:UAScheduleInfoLimitKey defaultValue:@(1)] unsignedIntegerValue];
        builder.priority = [[JSON numberForKey:UAScheduleInfoPriorityKey defaultValue:nil] integerValue];
        builder.editGracePeriod = [[JSON numberForKey:UAScheduleInfoEditGracePeriodKey defaultValue:nil] doubleValue] * 60 * 60 * 24;
        builder.interval = [[JSON numberForKey:UAScheduleInfoIntervalKey defaultValue:nil] doubleValue];
        builder.campaigns = [JSON dictionaryForKey:UAScheduleInfoCampaignsKey defaultValue:nil];
        builder.reportingContext = [JSON dictionaryForKey:UAScheduleInfoReportingContextKey defaultValue:nil];
        builder.audienceJSON = [JSON dictionaryForKey:UAScheduleInfoAudienceKey defaultValue:nil];
        builder.frequencyConstraintIDs = [JSON arrayForKey:UAScheduleInfoFrequencyConstraintIDsKey defaultValue:nil];

        if (JSON[UAScheduleInfoStartKey]) {
            builder.start = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoStartKey defaultValue:@""]];
        }

        if (JSON[UAScheduleInfoEndKey]) {
            builder.end = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoEndKey defaultValue:@""]];
        }

        builder.messageType = [JSON stringForKey:UAScheduleInfoMessageTypeKey defaultValue:nil];
        builder.bypassHoldoutGroups = [JSON numberForKey:UAScheduleInfoBypassHoldoutGroupsKey defaultValue:@NO].boolValue;
        builder.isNewUserEvaluationDate = newUserEvaluationDate;
        builder.productId = [JSON stringForKey:UAScheduleInfoProducId defaultValue:nil];
    }];
}

+ (UAScheduleEdits *)parseScheduleEditsWithJSON:(id)JSON
                                       metadata:(NSDictionary *)metadata
                          newUserEvaluationDate:(NSDate *)newUserEvaluationDate {
    return [UAInAppRemoteDataClient editsWithJSON:JSON builderBlock:^(UAScheduleEditsBuilder * _Nonnull builder) {
        builder.metadata = metadata;
        builder.limit = [JSON numberForKey:UAScheduleInfoLimitKey defaultValue:@(1)];
        builder.priority = [JSON numberForKey:UAScheduleInfoPriorityKey defaultValue:@(0)];
        builder.interval = [JSON numberForKey:UAScheduleInfoIntervalKey defaultValue:@(0)];
        builder.audienceJSON = [JSON dictionaryForKey:UAScheduleInfoAudienceKey defaultValue:nil];
        builder.campaigns = [JSON dictionaryForKey:UAScheduleInfoCampaignsKey defaultValue:@{}];
        builder.reportingContext = [JSON dictionaryForKey:UAScheduleInfoReportingContextKey defaultValue:nil];
        builder.frequencyConstraintIDs = [JSON arrayForKey:UAScheduleInfoFrequencyConstraintIDsKey defaultValue:@[]];

        NSNumber *gracePeriodDays = [JSON numberForKey:UAScheduleInfoEditGracePeriodKey defaultValue:@(14)];
        builder.editGracePeriod = @(gracePeriodDays.doubleValue * 60 * 60 * 24);

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
        
        if (JSON[UAScheduleInfoTriggeredTimeKey]) {
            builder.triggeredTime = [UAUtils parseISO8601DateFromString:[JSON stringForKey:UAScheduleInfoTriggeredTimeKey defaultValue:@""]];
        } else {
            builder.triggeredTime = [NSDate distantPast];
        }

        builder.messageType = [JSON stringForKey:UAScheduleInfoMessageTypeKey defaultValue:nil];
        builder.bypassHoldoutGroups = [JSON numberForKey:UAScheduleInfoBypassHoldoutGroupsKey defaultValue:nil];
        builder.isNewUserEvaluationDate = newUserEvaluationDate;
        builder.productId = [JSON stringForKey:UAScheduleInfoProducId defaultValue:nil];
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

    UA_LINFO(@"Invalid schedule: %@ error: %@", JSON, error);
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
