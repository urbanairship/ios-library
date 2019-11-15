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

NSTimeInterval const k24HoursInSeconds = 24 * 60 * 60;

NSString *const UAChannelRegistrarChannelIDKey = @"UAChannelID";
NSString *const UALastSuccessfulUpdateKey = @"last-update-key";
NSString *const UALastSuccessfulPayloadKey = @"payload-key";

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
 * A flag indicating if registration is in progress.
 */
@property (atomic, assign) BOOL isRegistrationInProgress;

/**
 * Background task identifier used to do any registration in the background.
 */
@property (nonatomic, assign) UIBackgroundTaskIdentifier registrationBackgroundTask;

/**
 * The channel API client.
 */
@property (nonatomic, strong) UAChannelAPIClient *channelAPIClient;

/**
 * A UADate object.
 */
@property (nonatomic, strong) UADate *date;

/**
 * The dispatcher to dispatch main queue blocks.
 */
@property (nonnull, strong) UADispatcher *dispatcher;

/**
 * The application
 */
@property (nonnull, strong) UIApplication *application;

@end

UARuntimeConfig *config;

@implementation UAChannelRegistrar

- (id)initWithDataStore:(UAPreferenceDataStore *)dataStore
       channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                   date:(UADate *)date
             dispatcher:(UADispatcher *)dispatcher
            application:(UIApplication *)application {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.channelAPIClient = channelAPIClient;
        self.date = date;
        self.dispatcher = dispatcher;
        self.application = application;

        self.isRegistrationInProgress = NO;
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }

    return self;
}

+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore
                          channelAPIClient:[UAChannelAPIClient clientWithConfig:config]
                                      date:[[UADate alloc] init]
                                dispatcher:[UADispatcher mainDispatcher]
                               application:[UIApplication sharedApplication]];
}

// Constructor for unit tests
+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                 channelID:(NSString *)channelID
                          channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                                      date:(UADate *)date
                                dispatcher:(UADispatcher *)dispatcher
                               application:(UIApplication *)application {

    UAChannelRegistrar *channelRegistrar =  [[self alloc] initWithDataStore:dataStore
                                                           channelAPIClient:channelAPIClient
                                                                       date:date
                                                                 dispatcher:dispatcher
                                                                application:application];
    channelRegistrar.channelID = channelID;
    return channelRegistrar;
}

#pragma mark -
#pragma mark API Methods

- (void)registerForcefully:(BOOL)forcefully {
    if (self.isRegistrationInProgress) {
        UA_LDEBUG(@"Ignoring registration request, one already in progress.");
        return;
    }

    UA_WEAKIFY(self)
    [self.delegate createChannelPayload:^(UAChannelRegistrationPayload *payload) {
        if (self.isRegistrationInProgress) {
            UA_LDEBUG(@"Ignoring registration request, one already in progress.");
            return;
        }

        UA_STRONGIFY(self)
        if (!forcefully && ![self shouldUpdateRegistration:payload]) {
            UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
            return;
        } else if (![self beginRegistrationBackgroundTask]) {
            UA_LDEBUG(@"Unable to perform registration, background task not granted.");
            return;
        }

        // Proceed with registration
        self.isRegistrationInProgress = YES;
        if (!self.channelID) {
            [self createChannelWithPayload:payload];
        } else {
            [self updateChannelWithPayload:payload];
        }
    } dispatcher:self.dispatcher];
}

- (void)cancelAllRequests {
    [self.channelAPIClient cancelAllRequests];

    // If a registration was in progress, its undeterministic if it succeeded
    // or not, so just clear the last success payload and time.
    if (self.isRegistrationInProgress) {
        self.lastSuccessfulPayload = nil;
        self.lastSuccessfulUpdateDate = [NSDate distantPast];
    }

    self.isRegistrationInProgress = NO;
}

- (void)resetChannel {
    [self cancelAllRequests];

    UA_LDEBUG(@"Clearing previous channel.");
    [self.dataStore removeObjectForKey:UAChannelRegistrarChannelIDKey];

    [self registerForcefully:YES];
}

#pragma mark -
#pragma mark Internal Methods

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

- (BOOL)beginRegistrationBackgroundTask {
    if (self.registrationBackgroundTask == UIBackgroundTaskInvalid) {
        UA_WEAKIFY(self)
        self.registrationBackgroundTask = [self.application beginBackgroundTaskWithExpirationHandler:^{
            UA_STRONGIFY(self)
            [self cancelAllRequests];
            [self.application endBackgroundTask:self.registrationBackgroundTask];
            self.registrationBackgroundTask = UIBackgroundTaskInvalid;
        }];
    }

    return (BOOL) self.registrationBackgroundTask != UIBackgroundTaskInvalid;
}

- (void)endRegistrationBackgroundTask {
    if (self.registrationBackgroundTask != UIBackgroundTaskInvalid) {
        [self.application endBackgroundTask:self.registrationBackgroundTask];
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }
}

// Must be called on main queue
- (void)updateChannelWithPayload:(UAChannelRegistrationPayload *)payload {
    UA_WEAKIFY(self);

    UAChannelRegistrationPayload *minPayload = [payload minimalUpdatePayloadWithLastPayload:self.lastSuccessfulPayload];

    UAChannelAPIClientUpdateSuccessBlock updateChannelSuccessBlock = ^{
        UA_STRONGIFY(self);
        [self.dispatcher dispatchAsync:^{
            UA_STRONGIFY(self);
            [self succeededWithPayload:payload];
        }];
    };

    UAChannelAPIClientFailureBlock updateChannelFailureBlock = ^(NSUInteger statusCode) {
        UA_STRONGIFY(self);
        [self.dispatcher dispatchAsync:^{
            UA_STRONGIFY(self);
            if (statusCode == 409) {
                UA_LTRACE(@"Channel conflict, recreating.");
                [self createChannelWithPayload:payload];
            } else {
                [self failedWithPayload:payload];
            }
        }];
    };

    [self.channelAPIClient updateChannelWithID:self.channelID
                                   withPayload:minPayload
                                     onSuccess:updateChannelSuccessBlock
                                     onFailure:updateChannelFailureBlock];
}

// Must be called on main queue
- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload {
    UA_WEAKIFY(self);

    UAChannelAPIClientCreateSuccessBlock createChannelSuccessBlock = ^(NSString *newChannelID, BOOL existing) {
        UA_STRONGIFY(self);
        [self.dispatcher dispatchAsync:^{
            UA_STRONGIFY(self);
            if (!newChannelID) {
                UA_LDEBUG(@"Channel ID is missing. Channel creation failed.");
                [self failedWithPayload:payload];
            } else {
                UA_LDEBUG(@"Channel %@ created successfully.", newChannelID);
                self.channelID = newChannelID;

                [self.delegate channelCreated:newChannelID existing:existing];
                [self succeededWithPayload:payload];
            }
        }];
    };

    UAChannelAPIClientFailureBlock createChannelFailureBlock = ^(NSUInteger statusCode) {
        UA_STRONGIFY(self);
        UA_LDEBUG(@"Channel creation failed.");
        [self.dispatcher dispatchAsync:^{
            UA_STRONGIFY(self);
            [self failedWithPayload:payload];
        }];
    };

    [self.channelAPIClient createChannelWithPayload:payload
                                          onSuccess:createChannelSuccessBlock
                                          onFailure:createChannelFailureBlock];
}

// Must be called on main queue
- (void)failedWithPayload:(UAChannelRegistrationPayload *)payload {
    self.isRegistrationInProgress = NO;
    [self.delegate registrationFailed];
    [self endRegistrationBackgroundTask];
}

// Must be called on main queue
- (void)succeededWithPayload:(UAChannelRegistrationPayload *)payload {
    self.lastSuccessfulPayload = payload;
    self.lastSuccessfulUpdateDate = [self.date now];

    id<UAChannelRegistrarDelegate> delegate = self.delegate;
    [delegate registrationSucceeded];

    UA_WEAKIFY(self)
    [delegate createChannelPayload:^(UAChannelRegistrationPayload *currentPayload) {
        UA_STRONGIFY(self)
        if ([self shouldUpdateRegistration:currentPayload]) {
            [self updateChannelWithPayload:currentPayload];
        } else {
            self.isRegistrationInProgress = NO;
            [self endRegistrationBackgroundTask];
        }
    } dispatcher:self.dispatcher];
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

