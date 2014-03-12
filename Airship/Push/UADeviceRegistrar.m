/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
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
            UA_LDEBUG(@"Unable to perform registration, one is already in progress.");
            return;
        }

        if (forcefully || [self shouldRegisterPayload:payloadCopy pushEnabled:YES]) {

            [self beginBackgroundTask];

            self.isRegistrationInProgress = YES;

            // Fallback to old device registration
            if (!self.isUsingChannelRegistration) {
                [self registerDeviceTokenWithChannelPayload:payloadCopy];
                return;
            }

            if (!channelID) {
                // Try to create a channel, fall back to registering the device token
                [self createChannelWithPayload:payloadCopy fallBackBlock:^(UAChannelRegistrationPayload *payload) {
                    [self registerDeviceTokenWithChannelPayload:payload];
                }];
            } else {
                [self updateChannel:channelID channelLocation:channelLocation withPayload:payloadCopy];
            }

        } else {
            UA_LDEBUG(@"Ignoring duplicate update request.");
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
            UA_LDEBUG(@"Unable to perform registration, one is already in progress.");
            return;
        }

        if (forcefully || [self shouldRegisterPayload:payloadCopy pushEnabled:NO]) {
            self.isRegistrationInProgress = YES;

            // Fallback to old device registration
            if (!self.isUsingChannelRegistration) {
                [self unregisterDeviceTokenWithChannelPayload:payloadCopy];
                return;
            }

            if (!channelID) {
                // Try to create a channel, fall back to unregistering the device token
                [self createChannelWithPayload:payloadCopy fallBackBlock:^(UAChannelRegistrationPayload *payload) {
                    [self unregisterDeviceTokenWithChannelPayload:payload];
                }];
            } else {
                [self updateChannel:channelID channelLocation:channelLocation withPayload:payloadCopy];
            }

        } else {
            UA_LDEBUG(@"Ignoring duplicate update request.");
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

        [self endBackgroundTask];
    }
}

- (void)updateChannel:(NSString *)channelID
      channelLocation:(NSString *)location
          withPayload:(UAChannelRegistrationPayload *)payload {

    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        UA_LTRACE(@"Channel %@ updated successfully.", channelID);
        [self succeededWithPayload:payload];
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        if (request.response.statusCode != 409) {
            [UAUtils logFailedRequest:request withMessage:@"updating channel"];
            [self failedWithPayload:payload];
            return;
        }

        // Conflict with channel id, create a new one
        UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *newChannelID, NSString *newChannelLocation) {
            UA_LTRACE(@"Channel %@ created successfully. Channel location: %@.", newChannelID, newChannelLocation);
            [self channelCreated:newChannelID channelLocation:newChannelLocation];
            [self succeededWithPayload:payload];
        };

        UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
            [UAUtils logFailedRequest:request withMessage:@"creating channel"];
            [self failedWithPayload:payload];
        };

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

    UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *channelID, NSString *channelLocation) {
        UA_LTRACE(@"Channel %@ created successfully. Channel location: %@.", channelID, channelLocation);
        [self channelCreated:channelID channelLocation:channelLocation];
        [self succeededWithPayload:payload];
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        if (request.response.statusCode == 501 && fallBackBlock) {
            UA_LTRACE(@"Channel api not available, falling back to device token registration");
            self.isUsingChannelRegistration = NO;
            fallBackBlock(payload);
        } else {
            [UAUtils logFailedRequest:request withMessage:@"creating channel"];
            [self failedWithPayload:payload];
        }
    };

    [self.channelAPIClient createChannelWithPayload:payload
                                          onSuccess:successBlock
                                          onFailure:failureBlock];
}

// TODO: Remove this once device token registration is removed
- (void)unregisterDeviceTokenWithChannelPayload:(UAChannelRegistrationPayload *)payload {
    if (!self.isDeviceTokenRegistered) {
        UA_LDEBUG(@"Device token already unregistered, skipping.");
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
        UA_LTRACE(@"Device token unregistered with Urban Airship successfully.");
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

    NSString *deviceToken = payload.pushAddress;
    UADeviceRegistrationPayload *devicePayload = [UADeviceRegistrationPayload payloadFromChannelRegistrationPayload:payload];

    UADeviceAPIClientSuccessBlock successBlock = ^{
        UA_LDEBUG(@"Device token registered on Urban Airship successfully.");
        self.deviceTokenRegistered = YES;
        [self succeededWithPayload:payload];
    };

    UADeviceAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        [UAUtils logFailedRequest:request withMessage:@"registering device token"];
        [self failedWithPayload:payload];
    };

    [self.deviceAPIClient registerDeviceToken:deviceToken
                                  withPayload:devicePayload
                                    onSuccess:successBlock
                                    onFailure:failureBlock];
}

- (void)failedWithPayload:(UAChannelRegistrationPayload *)payload {
    @synchronized(self) {
        id strongDelegate = self.delegate;
        if ([strongDelegate respondsToSelector:@selector(registrationFailedWithPayload:)]) {
            [strongDelegate registrationFailedWithPayload:payload];
        }

        self.isRegistrationInProgress = NO;
        [self endBackgroundTask];
    }
}

- (void)succeededWithPayload:payload {
    @synchronized(self) {
        id strongDelegate = self.delegate;
        if ([strongDelegate respondsToSelector:@selector(registrationSucceededWithPayload:)]) {
            [strongDelegate registrationSucceededWithPayload:payload];
        }

        self.lastSuccessPayload = payload;
        self.isRegistrationInProgress = NO;
        [self endBackgroundTask];
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


- (void)beginBackgroundTask {
    if (self.registrationBackgroundTask == UIBackgroundTaskInvalid) {
        self.registrationBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self cancelAllRequests];
        }];
    }
}

- (void)endBackgroundTask {
    if (self.registrationBackgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.registrationBackgroundTask];
        self.registrationBackgroundTask = UIBackgroundTaskInvalid;
    }
}

@end
