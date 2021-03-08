/* Copyright Airship and Contributors */

#import "UAChannelRegistrar+Internal.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAGlobal.h"
#import "UAUtils+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UARuntimeConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UADate.h"
#import "UADispatcher.h"
#import "UATaskManager.h"
#import "UATask.h"
#import "UASemaphore.h"

NSTimeInterval const k24HoursInSeconds = 24 * 60 * 60;

NSString *const UAChannelRegistrarChannelIDKey = @"UAChannelID";
NSString *const UALastSuccessfulUpdateKey = @"last-update-key";
NSString *const UALastSuccessfulPayloadKey = @"payload-key";

static NSString * const UAChannelRegistrationTaskID = @"UAChannelRegistrar.registration";
static NSString * const UAChannelRegistrarTaskExtrasForcefully = @"forcefully";

@interface UAChannelRegistrar ()

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The channel ID for this device.
 */
@property (nonatomic, copy, nullable) NSString *channelID;

/**
 * The last successful payload that was registered.
 */
@property (nonatomic, strong, nullable) UAChannelRegistrationPayload *lastSuccessfulPayload;

/**
 * The date of the last successful update.
 */
@property (nonatomic, strong, nullable) NSDate *lastSuccessfulUpdateDate;

/**
 * The channel API client.
 */
@property (nonatomic, strong) UAChannelAPIClient *channelAPIClient;

/**
 * A UADate object.
 */
@property (nonatomic, strong) UADate *date;

/**
 * The private serial dispatcher.
 */
@property (nonnull, strong) UADispatcher *dispatcher;

/**
 * The task manager.
 */
@property (nonnull, strong) UATaskManager *taskManager;

@end

UARuntimeConfig *config;

@implementation UAChannelRegistrar

- (id)initWithDataStore:(UAPreferenceDataStore *)dataStore
       channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                   date:(UADate *)date
             dispatcher:(UADispatcher *)dispatcher
            taskManager:(UATaskManager *)taskManager {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.channelAPIClient = channelAPIClient;
        self.date = date;
        self.dispatcher = dispatcher;
        self.taskManager = taskManager;

        [self registerTasks];
    }

    return self;
}

+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore
                          channelAPIClient:[UAChannelAPIClient clientWithConfig:config]
                                      date:[[UADate alloc] init]
                                dispatcher:[UADispatcher serialDispatcher]
                               taskManager:[UATaskManager shared]];
}

// Constructor for unit tests
+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                          channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                                      date:(UADate *)date
                                dispatcher:(UADispatcher *)dispatcher
                               taskManager:(UATaskManager *)taskManager {

    return [[self alloc] initWithDataStore:dataStore
                          channelAPIClient:channelAPIClient
                                      date:date
                                dispatcher:dispatcher
                               taskManager:taskManager];
}

#pragma mark -
#pragma mark API Methods

- (void)registerForcefully:(BOOL)forcefully {
    [self enqueueChannelRegistrationTask:forcefully];
}

- (void)resetChannel {
    [self.dispatcher dispatchAsync:^{
        UA_LDEBUG(@"Clearing previous channel.");
        [self clearChannelData];
        [self registerForcefully:YES];
    }];
}


- (void)clearChannelData {
    self.channelID = nil;
    self.lastSuccessfulPayload = nil;
    self.lastSuccessfulUpdateDate = [NSDate distantPast];
}
#pragma mark -
#pragma mark Internal Methods

- (UAChannelRegistrationPayload *)createPayload {
    __block UAChannelRegistrationPayload *result;
    UASemaphore *semaphore = [UASemaphore semaphore];

    [self.delegate createChannelPayload:^(UAChannelRegistrationPayload *payload) {
        result = payload;
        [semaphore signal];
    }];

    [semaphore wait];

    return result;
}

- (void)registerTasks {
    UA_WEAKIFY(self)
    [self.taskManager registerForTaskWithIDs:@[UAChannelRegistrationTaskID]
                                  dispatcher:self.dispatcher
                               launchHandler:^(id<UATask> task) {
        UA_STRONGIFY(self)
        if ([task.taskID isEqualToString:UAChannelRegistrationTaskID]) {
            [self handleRegistrationTask:task];
        } else {
            UA_LERR(@"Invalid task: %@", task.taskID);
            [task taskCompleted];
        }
    }];
}

- (void)handleRegistrationTask:(id<UATask>)task {
    NSDictionary *extras = task.requestOptions.extras;
    UA_LTRACE(@"Handle registration task: %@", extras);

    BOOL forcefully = [extras[UAChannelRegistrarTaskExtrasForcefully] boolValue];

    NSString *channelID = self.channelID;
    UAChannelRegistrationPayload *payload = [self createPayload];
    UAChannelRegistrationPayload *lastSuccessfulPayload = self.lastSuccessfulPayload;
    BOOL shouldUpdateRegistration = [self shouldUpdateRegistration:payload];

    if (!forcefully && !shouldUpdateRegistration) {
        UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
        [task taskCompleted];
        return;
    }

    if (channelID) {
        [self updateChannelWithPayload:payload lastSuccessfulPayload:lastSuccessfulPayload identifier:channelID task:task];
    } else {
        [self createChannelWithPayload:payload task:task];
    }
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload task:(id<UATask>)task {
    UASemaphore *semaphore = [UASemaphore semaphore];
    UADisposable *disposable = [self.channelAPIClient createChannelWithPayload:payload
                                                             completionHandler:^(UAChannelCreateResponse * _Nullable response, NSError * _Nullable error) {

        if (error) {
            UA_LDEBUG(@"Channel creation failed with error: %@", error);
            [self failedWithPayload:payload];
            [task taskFailed];
        } else if (response.isSuccess) {
            UA_LDEBUG(@"Channel %@ created successfully.", response.channelID);
            self.channelID = response.channelID;
            [self.delegate channelCreated:response.channelID existing:response.status == 200];
            [self succeededWithPayload:payload];
            [task taskCompleted];
        } else {
            UA_LDEBUG(@"Channel creation failed with response: %@.", response);
            [self failedWithPayload:payload];

            if (response.isServerError || response.status == 429) {
                [task taskFailed];
            } else {
                [task taskCompleted];
            }
        }

        [semaphore signal];
    }];

    task.expirationHandler = ^{
        [disposable dispose];
    };

    [semaphore wait];
}

- (void)updateChannelWithPayload:(UAChannelRegistrationPayload *)payload
           lastSuccessfulPayload:(UAChannelRegistrationPayload *)lastSuccessfulPayload
                      identifier:(NSString *)identifier
                            task:(id<UATask>)task {
    UASemaphore *semaphore = [UASemaphore semaphore];
    UAChannelRegistrationPayload *minPayload = [payload minimalUpdatePayloadWithLastPayload:lastSuccessfulPayload];

    UADisposable *disposable = [self.channelAPIClient updateChannelWithID:identifier
                                                              withPayload:minPayload
                                                        completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {

        if (error) {
            UA_LDEBUG(@"Channel creation failed with error: %@", error);
            [self failedWithPayload:payload];
            [task taskFailed];
        } else if (response.isSuccess) {
            UA_LDEBUG(@"Channel updated successfully.");
            [self succeededWithPayload:payload];
            [task taskCompleted];
        } else if (response.status == 409){
            UA_LTRACE(@"Channel conflict, recreating.");
            [self clearChannelData];
            [self registerForcefully:YES];
            [task taskCompleted];
        } else {
            UA_LDEBUG(@"Channel update failed with response: %@.", response);
            [self failedWithPayload:payload];
            if (response.isServerError || response.status == 429) {
                [task taskFailed];
            } else {
                [task taskCompleted];
            }
        }
        [semaphore signal];
    }];

    task.expirationHandler = ^{
        [disposable dispose];
    };

    [semaphore wait];
}

- (BOOL)shouldUpdateRegistration:(UAChannelRegistrationPayload *)payload {
    NSTimeInterval timeSinceLastUpdate = [[self.date now] timeIntervalSinceDate:self.lastSuccessfulUpdateDate];

    if (self.lastSuccessfulPayload == nil) {
        UA_LTRACE(@"Should update registration. Last payload is nil.");
        return true;
    }

    if (![payload isEqualToPayload:self.lastSuccessfulPayload]) {
        UA_LTRACE(@"Should update registration. Channel registration payload has changed.");
        return true;
    }

    if (timeSinceLastUpdate >= k24HoursInSeconds) {
        UA_LTRACE(@"Should update registration. Time since last registration time is greater than 24 hours.");
        return true;
    }

    return false;
}

- (void)enqueueChannelRegistrationTask {
    [self enqueueChannelRegistrationTask:NO];
}

- (void)enqueueChannelRegistrationTask:(BOOL)forcefully {
    id extras = @{UAChannelRegistrarTaskExtrasForcefully : @(forcefully)};

    UATaskConflictPolicy policy = forcefully ? UATaskConflictPolicyReplace : UATaskConflictPolicyKeep;

    UATaskRequestOptions *requestOptions = [UATaskRequestOptions optionsWithConflictPolicy:policy
                                                                           requiresNetwork:YES
                                                                                    extras:extras];

    [self.taskManager enqueueRequestWithID:UAChannelRegistrationTaskID options:requestOptions];
}

- (void)failedWithPayload:(UAChannelRegistrationPayload *)payload {
    [self.delegate registrationFailed];
}

- (void)succeededWithPayload:(UAChannelRegistrationPayload *)payload {
    self.lastSuccessfulPayload = payload;
    self.lastSuccessfulUpdateDate = [self.date now];

    id<UAChannelRegistrarDelegate> delegate = self.delegate;
    [delegate registrationSucceeded];

    UAChannelRegistrationPayload *currentPayload = [self createPayload];

    if ([self shouldUpdateRegistration:currentPayload]) {
        [self enqueueChannelRegistrationTask];
    }
}


#pragma mark -
#pragma mark Get/Set Methods

///---------------------------------------------------------------------------------------
/// @name Computed properties (stored in preference datastore)
///---------------------------------------------------------------------------------------
- (void)setChannelID:(NSString *)channelID {
    [self.dataStore setValue:channelID forKey:UAChannelRegistrarChannelIDKey];
    // Log the channel ID at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Channel ID: %@", channelID);
    }
}

- (NSString *)channelID {
    return [self.dataStore stringForKey:UAChannelRegistrarChannelIDKey];
}

- (UAChannelRegistrationPayload *)lastSuccessfulPayload {
    NSData *payloadData = [self.dataStore objectForKey:UALastSuccessfulPayloadKey];

    if (payloadData == nil || ![payloadData isKindOfClass:[NSData class]]) {
        return nil;
    }

    return [UAChannelRegistrationPayload channelRegistrationPayloadWithData:payloadData];
}

- (void)setLastSuccessfulPayload:(UAChannelRegistrationPayload *)payload {
    [self.dataStore setObject:payload.asJSONData forKey:UALastSuccessfulPayloadKey];
}

- (NSDate *)lastSuccessfulUpdateDate {
    return [self.dataStore objectForKey:UALastSuccessfulUpdateKey] ?: [NSDate distantPast];
}

- (void)setLastSuccessfulUpdateDate:(NSDate *)date {
    [self.dataStore setObject:date forKey:UALastSuccessfulUpdateKey];
}

@end

