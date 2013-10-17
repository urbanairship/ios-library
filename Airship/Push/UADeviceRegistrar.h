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

#import <Foundation/Foundation.h>


@class UAChannelRegistrationPayload;
@class UAHTTPRequest;

//---------------------------------------------------------------------------------------
// UARegistrationDelegate Protocol
//---------------------------------------------------------------------------------------

/**
 * Implement this protocol and add as a [UAPush registrationDelegate] to receive
 * device token registration success and failure callbacks.
 *
 */
@protocol UARegistrationDelegate<NSObject>
@optional

/**
 * Called when the channel is successfully registered with Urban Airship.
 */
- (void)registerChannelSucceeded;

/**
 * Called when the channel fails to register with Urban Airship and will not be
 * retried.
 *
 * @param request The failed request.
 */
- (void)registerChannelFailed:(UAHTTPRequest *)request;


/**
 * Called when the device token is successfully registered with Urban Airship.
 */
- (void)registerDeviceTokenSucceeded;


/**
 * Called when the device token registration fails.
 *
 * @param request The failed request.
 */
- (void)registerDeviceTokenFailed:(UAHTTPRequest *)request;

/**
 * Called when the device token is successfully deactivated with Urban Airship.
 */
- (void)unregisterDeviceTokenSucceeded;

/**
 * Called when the device token deactivation fails and cannot be retried.
 *
 * @param request The failed request.
 */
- (void)unregisterDeviceTokenFailed:(UAHTTPRequest *)request;
@end


//---------------------------------------------------------------------------------------
// UADeviceRegistrarDelegate Protocol
//---------------------------------------------------------------------------------------

@protocol UADeviceRegistrarDelegate<NSObject>
-(void)channelIDCreated:(NSString *)channelID;
@end

//---------------------------------------------------------------------------------------
// UADeviceRegistrar Interface
//---------------------------------------------------------------------------------------

@interface UADeviceRegistrar : NSObject

@property (nonatomic, assign) id<UARegistrationDelegate> registrationDelegate;
@property (nonatomic, assign) id<UADeviceRegistrarDelegate> registrarDelegate;

- (void)updateRegistrationWithChannelID:(NSString *)channelID
                            withPayload:(UAChannelRegistrationPayload *)payload
                            pushEnabled:(BOOL)pushEnabled
                             forcefully:(BOOL)forcefully;

@end


