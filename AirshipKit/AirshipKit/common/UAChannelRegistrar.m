/* Copyright Urban Airship and Contributors */

#import "UAChannelRegistrar+Internal.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAGlobal.h"
#import "UAUtils+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UADate+Internal.h"
#import "UADispatcher+Internal.h"

NSTimeInterval const k24HoursInSeconds = 24 * 60 * 60;

NSString *const UAPushChannelIDKey = @"UAChannelID";
NSString *const UAPushChannelLocationKey = @"UAChannelLocation";
NSString *const UALastSuccessfulUpdateKey = @"last-update-key";
NSString *const UALastSuccessfulPayloadKey = @"payload-key";

@interface UAChannelRegistrar ()

/**
 * The UAChannelRegistrarDelegate delegate.
 */
@property (nonatomic, weak, nullable) id<UAChannelRegistrarDelegate> delegate;

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The channel ID for this device.
 */
@property (nonatomic, copy, nullable) NSString *channelID;

/**
 * Channel location as a string.
 */
@property (nonatomic, copy, nullable) NSString *channelLocation;

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

UAConfig *config;

@implementation UAChannelRegistrar

- (id)initWithDataStore:(UAPreferenceDataStore *)dataStore
               delegate:(id<UAChannelRegistrarDelegate>)delegate
       channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                   date:(UADate *)date
             dispatcher:(UADispatcher *)dispatcher
            application:(UIApplication *)application {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.delegate = delegate;
        self.channelAPIClient = channelAPIClient;
        self.date = date;
        self.dispatcher = dispatcher;
        self.application = application;

        self.isRegistrationInProgress = NO;
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }

    return self;
}

+ (instancetype)channelRegistrarWithConfig:(UAConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                  delegate:(id<UAChannelRegistrarDelegate>)delegate {
    return [[self alloc] initWithDataStore:dataStore
                                  delegate:delegate
                          channelAPIClient:[UAChannelAPIClient clientWithConfig:config]
                                      date:[[UADate alloc] init]
                                dispatcher:[UADispatcher mainDispatcher]
                               application:[UIApplication sharedApplication]];
}

// Constructor for unit tests
+ (instancetype)channelRegistrarWithConfig:(UAConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                  delegate:(id<UAChannelRegistrarDelegate>)delegate
                                 channelID:(NSString *)channelID
                           channelLocation:(NSString *)channelLocation
                          channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                                      date:(UADate *)date
                                dispatcher:(UADispatcher *)dispatcher
                               application:(UIApplication *)application {

    UAChannelRegistrar *channelRegistrar =  [[self alloc] initWithDataStore:dataStore
                                                                   delegate:delegate
                                                           channelAPIClient:channelAPIClient
                                                                       date:date
                                                                 dispatcher:dispatcher
                                                                application:application];
    channelRegistrar.channelID = channelID;
    channelRegistrar.channelLocation = channelLocation;
    return channelRegistrar;

}

#pragma mark -
#pragma mark API Methods

- (void)registerForcefully:(BOOL)forcefully {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        if (self.isRegistrationInProgress) {
            UA_LDEBUG(@"Ignoring registration request, one already in progress.");
            return;
        }

        // proceed with registration
        self.isRegistrationInProgress = YES;

        UA_WEAKIFY(self)
        [self.delegate createChannelPayload:^(UAChannelRegistrationPayload *payload) {
            UA_STRONGIFY(self)

            if (!forcefully && ![self shouldUpdateRegistration:payload]) {
                UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
                return;
            } else if (![self beginRegistrationBackgroundTask]) {
                UA_LDEBUG(@"Unable to perform registration, background task not granted.");
                return;
            }

            if (!self.channelID || !self.channelLocation) {
                [self createChannelWithPayload:payload];
            } else {
                [self updateChannelWithPayload:payload];
            }
        }];
    }];
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
    [self.dataStore removeObjectForKey:UAPushChannelLocationKey];
    [self.dataStore removeObjectForKey:UAPushChannelIDKey];

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
    
    [self.channelAPIClient updateChannelWithLocation:self.channelLocation
                                         withPayload:payload
                                           onSuccess:updateChannelSuccessBlock
                                           onFailure:updateChannelFailureBlock];
}

// Must be called on main queue
- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload {
    UA_WEAKIFY(self);
    
    UAChannelAPIClientCreateSuccessBlock createChannelSuccessBlock = ^(NSString *newChannelID, NSString *newChannelLocation, BOOL existing) {
        UA_STRONGIFY(self);
        [self.dispatcher dispatchAsync:^{
            UA_STRONGIFY(self);
            if (!newChannelID || !newChannelLocation) {
                UA_LDEBUG(@"Channel ID: %@ or channel location: %@ is missing. Channel creation failed", newChannelID, newChannelLocation);
                [self failedWithPayload:payload];
            } else {
                UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", newChannelID, newChannelLocation);
                self.channelID = newChannelID;
                self.channelLocation = newChannelLocation;
                
                [self.delegate channelCreated:newChannelID channelLocation:newChannelLocation existing:existing];
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
    if (!self.isRegistrationInProgress) {
        return;
    }

    self.isRegistrationInProgress = NO;

    [self.delegate registrationFailed];
    
    [self endRegistrationBackgroundTask];
}

// Must be called on main queue
- (void)succeededWithPayload:(UAChannelRegistrationPayload *)payload {
    if (!self.isRegistrationInProgress) {
        return;
    }

    self.lastSuccessfulPayload = payload;
    self.lastSuccessfulUpdateDate = [self.date now];
    self.isRegistrationInProgress = NO;

    id<UAChannelRegistrarDelegate> delegate = self.delegate;
    [delegate registrationSucceeded];

    UA_WEAKIFY(self)
    [delegate createChannelPayload:^(UAChannelRegistrationPayload *currentPayload) {
        UA_STRONGIFY(self)
        if ([self shouldUpdateRegistration:currentPayload]) {
            [self updateChannelWithPayload:currentPayload];
        } else {
            [self endRegistrationBackgroundTask];
        }
    }];
}

#pragma mark -
#pragma mark Get/Set Methods

///---------------------------------------------------------------------------------------
/// @name Computed properties (stored in preference datastore)
///---------------------------------------------------------------------------------------
- (void)setChannelID:(NSString *)channelID {
    [self.dataStore setValue:channelID forKey:UAPushChannelIDKey];
    // Log the channel ID at error level, but without logging
    // it as an error.
    if (uaLogLevel >= UALogLevelError) {
        NSLog(@"Channel ID: %@", channelID);
    }
}

- (NSString *)channelID {
    // Get the channel location from data store instead of
    // the channelLocation property, because that may cause an infinite loop.
    if ([self.dataStore stringForKey:UAPushChannelLocationKey]) {
        return [self.dataStore stringForKey:UAPushChannelIDKey];
    } else {
        return nil;
    }
}

- (void)setChannelLocation:(NSString *)channelLocation {
    [self.dataStore setValue:channelLocation forKey:UAPushChannelLocationKey];
}

- (NSString *)channelLocation {
    // Get the channel location from data store instead of
    // the channelID property, because that may cause an infinite loop.
    if ([self.dataStore stringForKey:UAPushChannelIDKey]) {
        return [self.dataStore stringForKey:UAPushChannelLocationKey];
    } else {
        return nil;
    }
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
