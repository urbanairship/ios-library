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

NSString *const UADeviceTokenRegistered = @"UARegistrarDeviceTokenRegistered";

NSString * const UAChannelNotificationKey = @"channel_id";
NSString * const UAReplacedChannelNotificationKey = @"replaced_channel_id";

NSString * const UAChannelCreatedNotification = @"com.urbanairship.notification.channel_created";
NSString * const UAChannelConflictNotification = @"com.urbanairship.notification.channel_conflict";
NSString * const UADeviceRegistrationFinishedNotification = @"com.urbanairship.notification.registration_finished";

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

    @synchronized(self) {
        if (![self shouldSendUpdateWithPayload:payload] && !forcefully) {
            UA_LDEBUG(@"Ignoring duplicate update request.");
            [self registrationFinished];
            return;
        }

        [self cancelAllRequests];

        self.pendingPayload = payload;

        if (channelID) {
            [self updateChannel:channelID withPayload:self.pendingPayload];
        } else {
            // Try to create a channel, fall back to registering the device token
            [self createChannelWithPayload:self.pendingPayload pushEnabled:YES];
        }
    }
}

- (void)registerPushDisabledWithChannelID:(NSString *)channelID
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
        self.lastSuccessfulPayload = nil;

        [self cancelAllRequests];

        // Try to create a channel, fall back to unregistering the device token
        [self createChannelWithPayload:payload pushEnabled:NO];
    }
}

- (void)cancelAllRequests {
    [self.deviceAPIClient cancelAllRequests];
    [self.channelAPIClient cancelAllRequests];

    @synchronized(self) {
        // If we have a pending payload, its underministic if the request actually
        // went through to Urban Airship.  Clear both last success and pending.
        if (self.pendingPayload) {
            self.pendingPayload = nil;
            self.lastSuccessfulPayload = nil;
        }
    }
}

- (void)updateChannel:(NSString *)channelID
          withPayload:(UAChannelRegistrationPayload *)payload {

    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        UA_LTRACE(@"Channel %@ updated successfully.", channelID);
        [self succeededWithChannelID:channelID deviceToken:payload.pushAddress];
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        if (request.response.statusCode != 409) {
            [UAUtils logFailedRequest:request withMessage:@"updating channel"];
            [self failed];
            return;
        }

        // Conflict with channel id, create a new one
        UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *newChannelID){
            UA_LTRACE(@"Channel %@ created successfully.", newChannelID);
            [self channelConflict:channelID newChannel:newChannelID];
            [self succeededWithChannelID:newChannelID deviceToken:payload.pushAddress];
        };

        UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
            [UAUtils logFailedRequest:request withMessage:@"creating channel"];
            [self failed];
        };

        [self.channelAPIClient createChannelWithPayload:payload
                                              onSuccess:successBlock
                                              onFailure:failureBlock];
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
        [self channelCreated:channelID];
        [self succeededWithChannelID:channelID deviceToken:payload.pushAddress];
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        if (request.response.statusCode == 501) {
            UA_LTRACE(@"Channel api not available, falling back to device token registration");
            if (pushEnabled) {
                UADeviceRegistrationPayload *deviceRegistrationPayload = [UADeviceRegistrationPayload payloadFromChannelRegistrationPayload:payload];
                [self registerDeviceToken:payload.pushAddress withPayload:deviceRegistrationPayload];
            } else {
                [self unregisterDeviceToken:payload.pushAddress];
            }

        } else {
            [UAUtils logFailedRequest:request withMessage:@"creating channel"];
            [self failed];
        }
    };

    [self.channelAPIClient createChannelWithPayload:payload
                                          onSuccess:successBlock
                                          onFailure:failureBlock];
}

- (void)unregisterDeviceToken:(NSString *)deviceToken {
    if (!self.isDeviceTokenRegistered) {
        UA_LDEBUG(@"Device token already unregistered, skipping.");
        [self registrationFinished];
        return;
    }

    // If there is no device token, and push has been enabled then disabled, which occurs in certain circumstances,
    // most notably when a developer registers for UIRemoteNotificationTypeNone and this is the first install of an app
    // that uses push, the DELETE will fail with a 404.
    if (!deviceToken) {
        UA_LDEBUG(@"Device token is nil, unregistering with Urban Airship not possible. It is likely the app is already unregistered");
        [self registrationFinished];
        return;
    }

    UADeviceAPIClientSuccessBlock successBlock = ^{
        UA_LTRACE(@"Device token unregistered with Urban Airship successfully.");
        self.deviceTokenRegistered = NO;
        [self succeededWithChannelID:nil deviceToken:deviceToken];
    };

    UADeviceAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        [UAUtils logFailedRequest:request withMessage:@"unregistering device token"];
        [self failed];
    };

    [self.deviceAPIClient unregisterDeviceToken:deviceToken
                                      onSuccess:successBlock
                                      onFailure:failureBlock];
}

- (void)registerDeviceToken:(NSString *)deviceToken withPayload:(UADeviceRegistrationPayload *)payload {
    // If there is no device token, wait for the application delegate to update with one.
    if (!deviceToken) {
        UA_LDEBUG(@"Device token is nil. Registration will be attempted at a later time");
        [self registrationFinished];
        return;
    }

    UADeviceAPIClientSuccessBlock successBlock = ^{
        UA_LDEBUG(@"Device token registered on Urban Airship successfully.");
        self.deviceTokenRegistered = YES;
        [self succeededWithChannelID:nil deviceToken:deviceToken];

    };

    UADeviceAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        [UAUtils logFailedRequest:request withMessage:@"registering device token"];
        [self failed];
    };

    [self.deviceAPIClient registerDeviceToken:deviceToken
                                  withPayload:payload
                                    onSuccess:successBlock
                                    onFailure:failureBlock];
}

- (void)failed {
    @synchronized(self) {
        self.pendingPayload = nil;
    }
    
    id strongDelegate = self.registrationDelegate;
    if ([strongDelegate respondsToSelector:@selector(registrationFailed)]) {
        [strongDelegate registrationFailed];
    }
    [self registrationFinished];
}

- (void)succeededWithChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken {
    @synchronized(self) {
        self.lastSuccessfulPayload = self.pendingPayload;
        self.pendingPayload = nil;
    }

    id strongDelegate = self.registrationDelegate;
    if ([strongDelegate respondsToSelector:@selector(registrationSucceededForChannelID:deviceToken:)]) {
        [strongDelegate registrationSucceededForChannelID:channelID deviceToken:deviceToken];
    }
    
    [self registrationFinished];
}

- (BOOL)shouldSendUpdateWithPayload:(UAChannelRegistrationPayload *)data {
    // If we do not have a pending payload check the last success payload
    if (!self.pendingPayload && [self.lastSuccessfulPayload isEqualToPayload:data]) {
        return NO;
    }

    // Check the current pending payload
    return (![self.pendingPayload isEqualToPayload:data]);
}

- (BOOL)isDeviceTokenRegistered {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UADeviceTokenRegistered];
}

- (void)setDeviceTokenRegistered:(BOOL)deviceTokenRegistered {
    [[NSUserDefaults standardUserDefaults] setBool:deviceTokenRegistered forKey:UADeviceTokenRegistered];
}

- (void)registrationFinished {
    [[NSNotificationCenter defaultCenter] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];
}

- (void)channelCreated:(NSString *)channelID {
    NSDictionary *userInfo = @{UAChannelNotificationKey: channelID};

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelCreatedNotification
                                                        object:nil
                                                      userInfo:userInfo];
}

- (void)channelConflict:(NSString *)currentChannelID newChannel:(NSString *)newChannelID {
    NSDictionary *userInfo = @{UAChannelNotificationKey: newChannelID,
                               UAReplacedChannelNotificationKey: currentChannelID};

    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelConflictNotification
                                                        object:nil
                                                      userInfo:userInfo];
}

@end
