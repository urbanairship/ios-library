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

/**
 * The key for the channel id in the posted NSNotification's user info
 * when a channel is created.
 */
extern NSString * const UAChannelNotificationKey;

/**
 * NSNotification posted when a channel has been created.
 */
extern NSString * const UAChannelCreatedNotification;

/**
 * NSNotification posted when a channel has been deleted.
 */
extern NSString * const UAChannelDeletedNotification;

/**
 * NSNotification posted when a device registration finishes.
 *
 * Note: this will be posted at the end of every registration call. Even if
 * a registration is skipped.
 */
extern NSString * const UADeviceRegistrationFinishedNotification;


//---------------------------------------------------------------------------------------
// UARegistrationDelegate
//---------------------------------------------------------------------------------------

/**
 * Implement this protocol and add as a [UAPush registrationDelegate] to receive
 * registration success and failure callbacks
 *
 */
@protocol UARegistrationDelegate <NSObject>
@optional

/**
 * Called when the device channel and/or device token successfully registers with
 * Urban Airship.  Successful registrations could be disabling push, enabling push,
 * or updating the device registration settings.
 *
 * A nil channel id indicates the channel creation failed and the old device token
 * registration is being used.
 *
 * Device token will only be available once the application successfully registers
 * with APNS.
 */
- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken;

/**
 * Called when the device channel and/or device token failed to register with
 * Urban Airship.
 */
- (void)registrationFailed;

@end

//---------------------------------------------------------------------------------------
// UADeviceRegistrar
//---------------------------------------------------------------------------------------


@interface UADeviceRegistrar : NSObject

/**
 * A UARegistrationDelegate delegate.
 */
@property (nonatomic, weak) id<UARegistrationDelegate> registrationDelegate;


/**
 * Register the device with Urban Airship.
 *
 * @param channelID The channel id to update.  If nil is supplied, a channel will be created.
 * @param payload The payload for the registration.
 * @param forcefully To force the registration, skipping duplicate request checks.
 */
- (void)registerWithChannelID:(NSString *)channelID
                  withPayload:(UAChannelRegistrationPayload *)payload
                   forcefully:(BOOL)forcefully;

/**
 * Register that push is disabled for the device with Urban Airship.
 *
 * @param channelID The channel id to update.  If nil is supplied, a channel will be created.
 * @param payload The payload for the registration.
 * @param forcefully To force the registration, skipping duplicate request checks.
 */
- (void)registerPushDisabledWithChannelID:(NSString *)channelID
                              withPayload:(UAChannelRegistrationPayload *)payload
                               forcefully:(BOOL)forcefully;


/**
 * Cancels all pending and current requests.  
 *
 * Note: this may or may not prevent the registration finished event and registration
 * delegate calls.
 */
- (void)cancelAllRequests;
@end

