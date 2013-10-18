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

#import "UADeviceRegistrar.h"
#import "UADeviceAPIClient.h"
#import "UAChannelAPIClient.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAChannelRegistrationPayload.h"
#import "UADeviceRegistrationPayload.h"

NSString *const UADeviceTokenRegistered = @"UARegistrarDeviceTokenRegistered";

@interface UADeviceRegistrar()
@property (nonatomic, strong) UADeviceAPIClient *deviceAPIClient;
@property (nonatomic, strong) UAChannelAPIClient *channelAPIClient;

@property(nonatomic, strong) UAChannelRegistrationPayload *lastSuccessfulPayload;
@property(nonatomic, strong) UAChannelRegistrationPayload *pendingPayload;

// Flag to keep existing behavior of not doing multiple DELETEs on device token
@property(nonatomic, assign) BOOL deviceTokenRegistered;

@end


@implementation UADeviceRegistrar

-(id)init {
    self = [super init];
    if (self) {
        self.deviceAPIClient = [[UADeviceAPIClient alloc] init];
        self.channelAPIClient = [[UAChannelAPIClient alloc] init];
    }
    return self;
}

- (void)registerWithChannelID:(NSString *)channelID
                  withPayload:(UAChannelRegistrationPayload *)payload
                   forcefully:(BOOL)forcefully {

    UAChannelRegistrationPayload *payloadCopy = [payload copy];

    @synchronized(self) {
        if (![self shouldSendUpdateWithPayload:payload] && !forcefully) {
            UA_LDEBUG(@"Ignoring duplicate update request.");
            return;
        }

        self.pendingPayload = payloadCopy;

        [self.deviceAPIClient cancelAllRequests];
        [self.channelAPIClient cancelAllRequests];

        if (channelID) {
            [self updateChannel:channelID withPayload:payload];
        } else {
            // Try to create a channel, fall back to registering the device token
            [self createChannelWithPayload:payload pushEnabled:YES];
        }
    }
}

- (void)unregisterWithChannelID:(NSString *)channelID
                    withPayload:(UAChannelRegistrationPayload *)payload
                     forcefully:(BOOL)forcefully {

    @synchronized(self) {
        // if we have a channel id, just update the channel with the payload
        if (channelID) {
            [self registerWithChannelID:channelID withPayload:payload forcefully:forcefully];
            return;
        }

        // If we dont have a channel, clear the cache and try to register.  If it
        // falls back to the device client, the deviceTokenRegistered will prevent
        // us from unregistering the device token twice.
        self.pendingPayload = nil;
        self.channelAPIClient = nil;

        [self.deviceAPIClient cancelAllRequests];
        [self.channelAPIClient cancelAllRequests];

        // Try to create a channel, fall back to unregistering the device token
        [self createChannelWithPayload:payload pushEnabled:NO];
    }
}

- (void)finish:(BOOL)isSuccess {
    @synchronized(self) {
        if (isSuccess) {
            self.lastSuccessfulPayload = self.pendingPayload;
        }
        self.pendingPayload = nil;
    }
}

- (void)updateChannel:(NSString *)channelID
          withPayload:(UAChannelRegistrationPayload *)payload {

    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        UA_LTRACE(@"Channel %@ updated successfully.", channelID);
        [self finish:YES];
        if ([self.registrationDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
            [self.registrationDelegate registrationSucceededForChannelID:channelID deviceToken:payload.pushAddress];
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        [UAUtils logFailedRequest:request withMessage:@"updating channel"];
        [self finish:NO];

        if ([self.registrationDelegate respondsToSelector:@selector(registrationFailed)]) {
            [self.registrationDelegate registrationFailed];
        }
    };

    [self.channelAPIClient updateChannel:channelID
                             withPayload:payload
                               onSuccess:successBlock
                               onFailure:failureBlock];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                     pushEnabled:(BOOL)pushEnabled {

    UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *channelID){
        UA_LTRACE(@"Channel %@ created successfully.", channelID);
        [self finish:YES];

        if (self.registrarDelegate) {
            [self.registrarDelegate channelIDCreated:channelID];
        }

        if ([self.registrationDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
            [self.registrationDelegate registrationSucceededForChannelID:channelID deviceToken:payload.pushAddress];
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        if (request.response.statusCode == 501 || YES) {
            UA_LTRACE(@"Channel api not available, falling back to device token registration");
            if (pushEnabled) {
                UADeviceRegistrationPayload *deviceRegistrationPayload = [UADeviceRegistrationPayload payloadFromChannelRegistrationPayload:payload];
                [self registerDeviceToken:payload.pushAddress withPayload:deviceRegistrationPayload];
            } else {
                [self unregisterDeviceToken:payload.pushAddress];
            }

        } else {
            [UAUtils logFailedRequest:request withMessage:@"creating channel"];
            [self finish:NO];

            if ([self.registrationDelegate respondsToSelector:@selector(registrationFailed)]) {
                [self.registrationDelegate registrationFailed];
            }
        }

    };

    [self.channelAPIClient createChannelWithPayload:payload onSuccess:successBlock onFailure:failureBlock];
}

- (void)unregisterDeviceToken:(NSString *)deviceToken {
    // if the application is backgrounded, do not send a registration
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        UA_LDEBUG(@"Skipping device unregistration. The app is currently backgrounded.");
        [self finish:NO];
        return;
    }

    if (!self.deviceTokenRegistered) {
        UA_LDEBUG(@"Device token already unregistered, skipping.");
        [self finish:YES];
        return;
    }

    // If there is no device token, and push has been enabled then disabled, which occurs in certain circumstances,
    // most notably when a developer registers for UIRemoteNotificationTypeNone and this is the first install of an app
    // that uses push, the DELETE will fail with a 404.
    if (!deviceToken) {
        UA_LDEBUG(@"Device token is nil, unregistering with Urban Airship not possible. It is likely the app is already unregistered");
        [self finish:YES];
        return;
    }

    [self.deviceAPIClient
     unregisterDeviceToken:deviceToken
     onSuccess:^{
         UA_LTRACE(@"Device token unregistered with Urban Airship successfully.");

         self.deviceTokenRegistered = NO;
         [self finish:YES];

         if ([self.registrationDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
             [self.registrationDelegate registrationSucceededForChannelID:nil deviceToken:deviceToken];
         }
     }
     onFailure:^(UAHTTPRequest *request) {
         [UAUtils logFailedRequest:request withMessage:@"unregistering device token"];
         [self finish:NO];

         if ([self.registrationDelegate respondsToSelector:@selector(registrationFailed)]) {
             [self.registrationDelegate registrationFailed];
         }
     }];
}

- (void)registerDeviceToken:(NSString *)deviceToken withPayload:(UADeviceRegistrationPayload *)payload {
    // if the application is backgrounded, do not send a registration
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        UA_LDEBUG(@"Skipping device token registration. The app is currently backgrounded.");
        [self finish:NO];
        return;
    }

    // If there is no device token, wait for the application delegate to update with one.
    if (!deviceToken) {
        UA_LDEBUG(@"Device token is nil. Registration will be attempted at a later time");
        [self finish:NO];
        return;
    }

    [self.deviceAPIClient
     registerDeviceToken:deviceToken
     withPayload:payload
     onSuccess:^{
         UA_LDEBUG(@"Device token registered on Urban Airship successfully.");

         self.deviceTokenRegistered = YES;
         [self finish:YES];

         if ([self.registrationDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
             [self.registrationDelegate registrationSucceededForChannelID:nil deviceToken:deviceToken];
         }
     }
     onFailure:^(UAHTTPRequest *request) {
         [UAUtils logFailedRequest:request withMessage:@"registering device token"];
         [self finish:NO];

         if ([self.registrationDelegate respondsToSelector:@selector(registrationFailed)]) {
             [self.registrationDelegate registrationFailed];
         }
     }];
}

- (BOOL)shouldSendUpdateWithPayload:(UAChannelRegistrationPayload *)data {
    return !([self.pendingPayload isEqualToPayload:data]
             || [self.lastSuccessfulPayload isEqualToPayload:data]);
}

- (BOOL)deviceTokenRegistered {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UADeviceTokenRegistered];
}

- (void)setDeviceTokenRegistered:(BOOL)deviceTokenRegistered {
    [[NSUserDefaults standardUserDefaults] setBool:deviceTokenRegistered forKey:UADeviceTokenRegistered];
}


@end
