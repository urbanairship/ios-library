/* Copyright 2018 Urban Airship and Contributors */

#import "UAChannelRegistrar+Internal.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAGlobal.h"
#import "UAUtils+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"

NSTimeInterval const k24HoursInSeconds = 24 * 60 * 60;

NSString *const UALastSuccessfulUpdateKey = @"last-update-key";
NSString *const UALastSuccessfulPayloadKey = @"payload-key";

UAConfig *config;

@implementation UAChannelRegistrar

-(id)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.channelAPIClient = [UAChannelAPIClient clientWithConfig:config];
        self.isRegistrationInProgress = NO;
        self.dataStore = dataStore;
    }

    return self;
}

+ (instancetype)channelRegistrarWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAChannelRegistrar alloc] initWithConfig:config dataStore:dataStore];
}

- (BOOL)shouldUpdateRegistration:(UAChannelRegistrationPayload *)payload {
    NSTimeInterval timeSinceLastUpdate = [[NSDate date] timeIntervalSinceDate:self.lastSuccessfulUpdateDate];

    if (self.lastSuccessfulPayload == nil) {
        UA_LDEBUG(@"Should update registration. Last payload is nil.");
        return true;
    }

    if (![payload isEqualToPayload:self.lastSuccessfulPayload]) {
        UA_LDEBUG(@"Should update registration. Channel registration payload has changed.");
        return true;
    }

    if (timeSinceLastUpdate >= k24HoursInSeconds) {
        UA_LDEBUG(@"Should update registration. Time since last registration time is greater than 24 hours.");
        return true;
    }

    return false;
}

- (void)registerWithChannelID:(NSString *)channelID
              channelLocation:(NSString *)channelLocation
                  withPayload:(UAChannelRegistrationPayload *)payload
                   forcefully:(BOOL)forcefully {

    UAChannelRegistrationPayload *payloadCopy = [payload copy];

    if (self.isRegistrationInProgress) {
        UA_LDEBUG(@"Ignoring registration request, one already in progress.");
        return;
    }

    self.isRegistrationInProgress = YES;

    if (forcefully || [self shouldUpdateRegistration:payload]) {
        if (!channelID || !channelLocation) {
            [self createChannelWithPayload:payloadCopy];
        } else {
            [self updateChannel:channelID channelLocation:channelLocation withPayload:payloadCopy];
        }

    } else {
        UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
        [self succeededWithPayload:payload];
    }
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

- (void)updateChannel:(NSString *)channelID
      channelLocation:(NSString *)location
          withPayload:(UAChannelRegistrationPayload *)payload {
    UA_LDEBUG(@"Updating channel %@", channelID);

    UA_WEAKIFY(self);
    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            UA_STRONGIFY(self);
            [self succeededWithPayload:payload];
        });
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(NSUInteger statusCode) {

        if (statusCode != 409) {
            UA_LDEBUG(@"Channel failed to update with JSON payload %@", [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding]);

            dispatch_async(dispatch_get_main_queue(), ^{
                UA_STRONGIFY(self);
                [self failedWithPayload:payload];
            });

            return;
        }

        // Conflict with channel ID, create a new one
        UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *newChannelID, NSString *channelLocation, BOOL existing) {

            if (!channelID || !channelLocation) {
                UA_LDEBUG(@"Channel ID: %@ or channel location: %@ is missing. Channel creation failed", channelID, channelLocation);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UA_STRONGIFY(self);
                    [self failedWithPayload:payload];
                });

            } else {
                UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", newChannelID, channelLocation);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UA_STRONGIFY(self);
                    [self channelCreated:newChannelID channelLocation:channelLocation existing:existing];
                    [self succeededWithPayload:payload];
                });
            }
        };

        UAChannelAPIClientFailureBlock failureBlock = ^(NSUInteger statusCode) {
            UA_LDEBUG(@"Channel failed to create with JSON payload %@", [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding]);
            dispatch_async(dispatch_get_main_queue(), ^{
                UA_STRONGIFY(self);
                [self failedWithPayload:payload];
            });
        };

        UA_STRONGIFY(self);
        UA_LDEBUG(@"Channel conflict, recreating.");
        [self.channelAPIClient createChannelWithPayload:payload
                                              onSuccess:successBlock
                                              onFailure:failureBlock];
    };

    [self.channelAPIClient updateChannelWithLocation:location
                                         withPayload:payload
                                           onSuccess:successBlock
                                           onFailure:failureBlock];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload {

    UA_LDEBUG(@"Creating channel.");

    UA_WEAKIFY(self);

    UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *channelID, NSString *channelLocation, BOOL existing) {
        if (!channelID || !channelLocation) {
            UA_LDEBUG(@"Channel ID: %@ or channel location: %@ is missing. Channel creation failed", channelID, channelLocation);
            dispatch_async(dispatch_get_main_queue(), ^{
                UA_STRONGIFY(self);
                [self failedWithPayload:payload];
            });
        } else {
            UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", channelID, channelLocation);

            dispatch_async(dispatch_get_main_queue(), ^{
                UA_STRONGIFY(self);
                [self channelCreated:channelID channelLocation:channelLocation existing:existing];
                [self succeededWithPayload:payload];
            });
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(NSUInteger statusCode) {
        UA_LDEBUG(@"Channel creation failed.");
        dispatch_async(dispatch_get_main_queue(), ^{
            UA_STRONGIFY(self);
            [self failedWithPayload:payload];
        });
    };

    [self.channelAPIClient createChannelWithPayload:payload
                                          onSuccess:successBlock
                                          onFailure:failureBlock];
}

// Must be called on main queue
- (void)failedWithPayload:(UAChannelRegistrationPayload *)payload {
    if (!self.isRegistrationInProgress) {
        return;
    }

    self.isRegistrationInProgress = NO;

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(registrationFailedWithPayload:)]) {
        [strongDelegate registrationFailedWithPayload:payload];
    }
}

// Must be called on main queue
- (void)succeededWithPayload:(UAChannelRegistrationPayload *)payload {
    if (!self.isRegistrationInProgress) {
        return;
    }

    self.lastSuccessfulPayload = payload;
    self.lastSuccessfulUpdateDate = [NSDate date];
    self.isRegistrationInProgress = NO;

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(registrationSucceededWithPayload:)]) {
        [strongDelegate registrationSucceededWithPayload:payload];
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

// Must be called on main queue
- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
              existing:(BOOL)existing {

    id strongDelegate = self.delegate;

    if ([strongDelegate respondsToSelector:@selector(channelCreated:channelLocation:existing:)]) {
        [strongDelegate channelCreated:channelID channelLocation:channelLocation existing:existing];
    }
}

@end
