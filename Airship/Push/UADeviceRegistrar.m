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

@interface UADeviceRegistrar()
@property (nonatomic, strong) UADeviceAPIClient *deviceAPIClient;
@property (nonatomic, strong) UAChannelAPIClient *channelAPIClient;
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

- (void)updateRegistrationWithChannelID:(NSString *)channelID
                            withPayload:(UAChannelRegistrationPayload *)payload
                            pushEnabled:(BOOL)pushEnabled
                             forcefully:(BOOL)forcefully {

    if (channelID) {
        [self updateChannel:channelID withPayload:payload forcefully:forcefully];
    } else {
        [self createChannelWithPayload:payload pushEnabled:pushEnabled forcefully:forcefully];
    }
}


- (void)updateChannel:(NSString *)channelID
          withPayload:(UAChannelRegistrationPayload *)payload
           forcefully:(BOOL)forcefully {

    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        if ([self.registrationDelegate respondsToSelector:@selector(registerChannelSucceeded)]) {
            [self.registrationDelegate registerChannelSucceeded];
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        if ([self.registrationDelegate respondsToSelector:@selector(registerChannelFailed:)]) {
            [self.registrationDelegate registerChannelFailed:request];
        }
    };

    [self.channelAPIClient updateChannel:channelID
                             withPayload:payload
                               onSuccess:successBlock
                               onFailure:failureBlock
                              forcefully:forcefully];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                     pushEnabled:(BOOL)pushEnabled
                      forcefully:(BOOL)forcefully {

    UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *channelID){
        UA_LTRACE(@"Channel %@ created successfully.", channelID);

        if (self.registrarDelegate) {
            [self.registrarDelegate channelIDCreated:channelID];
        }

        if ([self.registrationDelegate respondsToSelector:@selector(registerChannelSucceeded)]) {
            [self.registrationDelegate registerChannelSucceeded];
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(UAHTTPRequest *request){
        if (request.response.statusCode == 501 || YES) {
            UA_LTRACE(@"Channel api not available, falling back to device token registration");
            UADeviceRegistrationData *deviceRegistrationData = [self createDeviceRegistrationDataFromChannelPayload:payload
                                                                                                        pushEnabled:pushEnabled];
            NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                if (pushEnabled) {
                    [self registerDeviceWithData:deviceRegistrationData forcefully:forcefully];
                } else {
                    [self unregisterDeviceWithData:deviceRegistrationData forcefully:forcefully];
                }
            }];

            [[NSOperationQueue mainQueue] addOperation:blockOperation];

        } else {
            [UAUtils logFailedRequest:request withMessage:@"creating channel"];

            if ([self.registrationDelegate respondsToSelector:@selector(registerChannelFailed:)]) {
                [self.registrationDelegate registerChannelFailed:request];
            }
        }

    };

    [self.channelAPIClient createChannelWithPayload:payload onSuccess:successBlock onFailure:failureBlock];
}

- (void)unregisterDeviceWithData:(UADeviceRegistrationData *)data forcefully:(BOOL)forcefully {
    // if the application is backgrounded, do not send a registration
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        UA_LDEBUG(@"Skipping device unregistration. The app is currently backgrounded.");
        return;
    }

    // If there is no device token, and push has been enabled then disabled, which occurs in certain circumstances,
    // most notably when a developer registers for UIRemoteNotificationTypeNone and this is the first install of an app
    // that uses push, the DELETE will fail with a 404.
    if (!data.deviceToken) {
        UA_LDEBUG(@"Device token is nil, unregistering with Urban Airship not possible. It is likely the app is already unregistered");
        return;
    }

    [self.deviceAPIClient
     unregisterWithData:data
     onSuccess:^{
         UA_LTRACE(@"Device token unregistered with Urban Airship successfully.");

         // note that unregistration is no longer needed
         if ([self.registrationDelegate respondsToSelector:@selector(unregisterDeviceTokenSucceeded)]) {
             [self.registrationDelegate unregisterDeviceTokenSucceeded];
         }
     }
     onFailure:^(UAHTTPRequest *request) {
         [UAUtils logFailedRequest:request withMessage:@"unregistering device token"];
         if ([self.registrationDelegate respondsToSelector:@selector(unregisterDeviceTokenFailed:)]) {
             [self.registrationDelegate unregisterDeviceTokenFailed:request];
         }
     }
     forcefully:forcefully];
}


- (void)registerDeviceWithData:(UADeviceRegistrationData *)data forcefully:(BOOL)forcefully {
    // if the application is backgrounded, do not send a registration
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        UA_LDEBUG(@"Skipping device token registration. The app is currently backgrounded.");
        return;
    }

    // If there is no device token, wait for the application delegate to update with one.
    if (!data.deviceToken) {
        UA_LDEBUG(@"Device token is nil. Registration will be attempted at a later time");
        return;
    }

    [self.deviceAPIClient
     registerWithData:data
     onSuccess:^{
         UA_LDEBUG(@"Device token registered on Urban Airship successfully.");
         if ([self.registrationDelegate respondsToSelector:@selector(registerDeviceTokenSucceeded)]) {
             [self.registrationDelegate registerDeviceTokenSucceeded];
         }
     }
     onFailure:^(UAHTTPRequest *request) {
         [UAUtils logFailedRequest:request withMessage:@"registering device token"];

         if ([self.registrationDelegate respondsToSelector:@selector(registerDeviceTokenFailed:)]) {
             [self.registrationDelegate registerDeviceTokenFailed:request];
         }
     }
     forcefully:forcefully];
}

- (UADeviceRegistrationData *)createDeviceRegistrationDataFromChannelPayload:(UAChannelRegistrationPayload *)payload
                                                                 pushEnabled:(BOOL)pushEnabled {


    NSArray *tags = payload.setTags ? payload.tags : nil;
    UADeviceRegistrationPayload *devicePayload = [UADeviceRegistrationPayload payloadWithAlias:payload.alias
                                                                                      withTags:tags
                                                                                  withTimeZone:payload.timeZone
                                                                                 withQuietTime:payload.quietTime
                                                                                     withBadge:payload.badge];

    return [UADeviceRegistrationData dataWithDeviceToken:payload.pushAddress
                                             withPayload:devicePayload
                                             pushEnabled:pushEnabled];
}

@end
