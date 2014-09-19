/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UADeviceRegistrar+Internal.h"
#import "UADeviceAPIClient.h"
#import "UAChannelAPIClient.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAChannelRegistrationPayload.h"
#import "UADeviceRegistrationPayload.h"

NSString * const UADeviceTokenRegistered = @"UARegistrarDeviceTokenRegistered";

@implementation UADeviceRegistrar

-(id)init {
    self = [super init];
    if (self) {
        self.deviceAPIClient = [[UADeviceAPIClient alloc] init];
        self.channelAPIClient = [[UAChannelAPIClient alloc] init];
        self.isUsingChannelRegistration = YES;
        self.isRegistrationInProgress = NO;
    }
    return self;
}

- (void)registerWithChannelID:(NSString *)channelID
              channelLocation:(NSString *)channelLocation
                  withPayload:(UAChannelRegistrationPayload *)payload
                   forcefully:(BOOL)forcefully {

    UAChannelRegistrationPayload *payloadCopy = [payload copy];

    @synchronized(self) {
        if (self.isRegistrationInProgress) {
            UA_LDEBUG(@"Ignoring registration request, one already in progress.");
            return;
        }

        self.isRegistrationInProgress = YES;

        if (forcefully || [self shouldRegisterPayload:payloadCopy pushEnabled:YES]) {


            // Fallback to old device registration
            if (!self.isUsingChannelRegistration) {
                [self registerDeviceTokenWithChannelPayload:payloadCopy];
                return;
            }

            if (!channelID || !channelLocation) {
                // Try to create a channel, fall back to registering the device token
                [self createChannelWithPayload:payloadCopy fallBackBlock:^(UAChannelRegistrationPayload *payload) {
                    [self registerDeviceTokenWithChannelPayload:payload];
                }];
            } else {
                [self updateChannel:channelID channelLocation:channelLocation withPayload:payloadCopy];
            }

        } else {
            UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
            [self succeededWithPayload:payload];
        }
    }
}


// TODO: remove this method once we remove device token registration
- (void)registerPushDisabledWithChannelID:(NSString *)channelID
                          channelLocation:(NSString *)channelLocation
                              withPayload:(UAChannelRegistrationPayload *)payload
                               forcefully:(BOOL)forcefully {

    UAChannelRegistrationPayload *payloadCopy = [payload copy];
    @synchronized(self) {
        if (self.isRegistrationInProgress) {
            UA_LDEBUG(@"Ignoring registration request, one already in progress.");
            return;
        }

        self.isRegistrationInProgress = YES;

        if (forcefully || [self shouldRegisterPayload:payloadCopy pushEnabled:NO]) {

            self.isRegistrationInProgress = YES;

            // Fallback to old device registration
            if (!self.isUsingChannelRegistration) {
                [self unregisterDeviceTokenWithChannelPayload:payloadCopy];
                return;
            }

            if (!channelID || !channelLocation) {
                // Try to create a channel, fall back to unregistering the device token
                [self createChannelWithPayload:payloadCopy fallBackBlock:^(UAChannelRegistrationPayload *payload) {
                    [self unregisterDeviceTokenWithChannelPayload:payload];
                }];
            } else {
                [self updateChannel:channelID channelLocation:channelLocation withPayload:payloadCopy];
            }

        } else {
            UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
            [self succeededWithPayload:payload];
        }
    }
}


- (void)cancelAllRequests {
    @synchronized(self) {
        [self.deviceAPIClient cancelAllRequests];
        [self.channelAPIClient cancelAllRequests];

        // If a registration was in progress, its undeterministic if it succeeded
        // or not, so just clear the last success payload.
        if (self.isRegistrationInProgress) {
            self.lastSuccessPayload = nil;
        }

        self.isRegistrationInProgress = NO;
    }
}

- (void)updateChannel:(NSString *)channelID
      channelLocation:(NSString *)location
          withPayload:(UAChannelRegistrationPayload *)payload {

    UA_LDEBUG(@"Updating channel %@", channelID);

    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        [self succeededWithPayload:payload];
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        if (request.response.statusCode != 409) {
            UA_LDEBUG(@"Channel failed to update with payload %@", payload);
            [self failedWithPayload:payload];
            return;
        }

        // Conflict with channel id, create a new one
        UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *newChannelID, NSString *newChannelLocation) {
            UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", newChannelID, newChannelLocation);
            [self channelCreated:newChannelID channelLocation:newChannelLocation];
            [self succeededWithPayload:payload];
        };

        UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
            UA_LDEBUG(@"Channel failed to create with payload %@", payload);
            [self failedWithPayload:payload];
        };

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

// TODO: Remove the fallback once device token registration is removed
- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                     fallBackBlock:(void (^)(UAChannelRegistrationPayload *))fallBackBlock {

    UA_LDEBUG(@"Creating channel.");

    UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *channelID, NSString *channelLocation) {
        if (!channelID || !channelLocation) {
            UA_LDEBUG(@"Channel ID: %@ or channel location: %@ is missing. Channel creation failed",
                      channelID, channelLocation);
            [self failedWithPayload:payload];
        } else {
            UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", channelID, channelLocation);
            [self channelCreated:channelID channelLocation:channelLocation];
            [self succeededWithPayload:payload];
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        if (request.response.statusCode == 501 && fallBackBlock) {
            UA_LDEBUG(@"Channel api not available, falling back to device token registration");
            self.isUsingChannelRegistration = NO;
            fallBackBlock(payload);
        } else {
            UA_LDEBUG(@"Channel creation failed.");
            [self failedWithPayload:payload];
        }
    };

    [self.channelAPIClient createChannelWithPayload:payload
                                          onSuccess:successBlock
                                          onFailure:failureBlock];
}

// TODO: Remove this once device token registration is removed
- (void)unregisterDeviceTokenWithChannelPayload:(UAChannelRegistrationPayload *)payload {
    UA_LDEBUG(@"Unregistering device token with Urban Airship.");

    if (!self.isDeviceTokenRegistered) {
        UA_LDEBUG(@"Device token already unregistered.");
        [self succeededWithPayload:payload];
        return;
    }

    // If there is no device token, and push has been enabled then disabled, which occurs in certain circumstances,
    // most notably when a developer registers for UIRemoteNotificationTypeNone and this is the first install of an app
    // that uses push, the DELETE will fail with a 404.
    if (!payload.pushAddress) {
        UA_LDEBUG(@"Device token is nil, unregistering with Urban Airship not possible. It is likely the app is already unregistered.");
        [self succeededWithPayload:payload];
        return;
    }

    UADeviceAPIClientSuccessBlock successBlock = ^{
        UA_LDEBUG(@"Device token unregistered with Urban Airship successfully.");
        self.deviceTokenRegistered = NO;
        [self succeededWithPayload:payload];
    };

    UADeviceAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        [UAUtils logFailedRequest:request withMessage:@"unregistering device token"];
        [self failedWithPayload:payload];
    };

    [self.deviceAPIClient unregisterDeviceToken:payload.pushAddress
                                      onSuccess:successBlock
                                      onFailure:failureBlock];
}

// TODO: Remove this once device token registration is removed
- (void)registerDeviceTokenWithChannelPayload:(UAChannelRegistrationPayload *)payload {
    // If there is no device token, wait for the application delegate to update with one.
    if (!payload.pushAddress) {
        UA_LDEBUG(@"Device token is nil. Registration will be attempted at a later time.");
        [self failedWithPayload:payload];
        return;
    }

    UA_LDEBUG(@"Registering device token with Urban Airship.");

    NSString *deviceToken = payload.pushAddress;
    UADeviceRegistrationPayload *devicePayload = [UADeviceRegistrationPayload payloadFromChannelRegistrationPayload:payload];

    UADeviceAPIClientSuccessBlock successBlock = ^{
        UA_LDEBUG(@"Device token registered on Urban Airship successfully.");
        self.deviceTokenRegistered = YES;
        [self succeededWithPayload:payload];
    };

    UADeviceAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        [self failedWithPayload:payload];
    };

    [self.deviceAPIClient registerDeviceToken:deviceToken
                                  withPayload:devicePayload
                                    onSuccess:successBlock
                                    onFailure:failureBlock];
}

- (void)failedWithPayload:(UAChannelRegistrationPayload *)payload {
    @synchronized(self) {
        if (!self.isRegistrationInProgress) {
            return;
        }

        self.isRegistrationInProgress = NO;

        id strongDelegate = self.delegate;
        if ([strongDelegate respondsToSelector:@selector(registrationFailedWithPayload:)]) {
            [strongDelegate registrationFailedWithPayload:payload];
        }
    }
}

- (void)succeededWithPayload:(UAChannelRegistrationPayload *)payload {
    @synchronized(self) {
        if (!self.isRegistrationInProgress) {
            return;
        }

        self.lastSuccessPayload = payload;
        self.isRegistrationInProgress = NO;

        id strongDelegate = self.delegate;
        if ([strongDelegate respondsToSelector:@selector(registrationSucceededWithPayload:)]) {
            [strongDelegate registrationSucceededWithPayload:payload];
        }
    }
}

- (void)channelCreated:(NSString *)channelID channelLocation:(NSString *)channelLocation {
    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(channelCreated:channelLocation:)]) {
        [strongDelegate channelCreated:channelID channelLocation:channelLocation];
    }

}

- (BOOL)shouldRegisterPayload:(UAChannelRegistrationPayload *)payload pushEnabled:(BOOL) pushEnabled {
    // If we are using old registration, then we need to make sure pushEnabled
    // matches if the device token is registered because the payload does not track
    // that.
    // TODO: Remove this once device token registration is removed
    if (!self.isUsingChannelRegistration && pushEnabled != self.isDeviceTokenRegistered) {
        return YES;
    }

    return ![payload isEqualToPayload:self.lastSuccessPayload];
}

// TODO: Remove this once device token registration is removed
- (BOOL)isDeviceTokenRegistered {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UADeviceTokenRegistered];
}

// TODO: Remove this once device token registration is removed
- (void)setDeviceTokenRegistered:(BOOL)deviceTokenRegistered {
    [[NSUserDefaults standardUserDefaults] setBool:deviceTokenRegistered forKey:UADeviceTokenRegistered];
}

@end
