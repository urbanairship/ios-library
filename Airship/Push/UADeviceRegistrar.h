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

#import <Foundation/Foundation.h>

@class UAChannelRegistrationPayload;

/**
 * The UADeviceRegistrarDelegate protocol for registration events.
 */
@protocol UADeviceRegistrarDelegate <NSObject>
@optional

/**
 * Called when the device registrar failed to register.
 * @param payload The registration payload.
 */
- (void)registrationFailedWithPayload:(UAChannelRegistrationPayload *)payload;

/**
 * Called when the device registrar succesfully registered.
 * @param payload The registration payload.
 */
- (void)registrationSucceededWithPayload:(UAChannelRegistrationPayload *)payload;

/**
 * Called when the device registrar creates a new channel.
 * @param channelID The channel ID string.
 * @param channelLocation The channel location string.
 */
- (void)channelCreated:(NSString *)channelID channelLocation:(NSString *)channelLocation;

@end

/**
 * The UADeviceRegistrar class is responsible for device registrations.
 */
@interface UADeviceRegistrar : NSObject

/**
 * A UADeviceRegistrarDelegate delegate.
 */
@property (nonatomic, weak) id<UADeviceRegistrarDelegate> delegate;

/**
 * Register the device with Urban Airship.
 *
 * @param channelID The channel id to update.  If nil is supplied, a channel will be created.
 * @param channelLocation The channel location.  If nil is supplied, a channel will be created.
 * @param payload The payload for the registration.
 * @param forcefully To force the registration, skipping duplicate request checks.
 */
- (void)registerWithChannelID:(NSString *)channelID
              channelLocation:(NSString *)channelLocation
                  withPayload:(UAChannelRegistrationPayload *)payload
                   forcefully:(BOOL)forcefully;

/**
 * Register that push is disabled for the device with Urban Airship.
 *
 * @param channelID The channel id to update.  If nil is supplied, a channel will be created.
 * @param channelLocation The channel location.  If nil is supplied, a channel will be created.
 * @param payload The payload for the registration.
 * @param forcefully To force the registration, skipping duplicate request checks.
 */
- (void)registerPushDisabledWithChannelID:(NSString *)channelID
                          channelLocation:(NSString *)channelLocation
                              withPayload:(UAChannelRegistrationPayload *)payload
                               forcefully:(BOOL)forcefully;

/**
 * Cancels all pending and current requests.  
 *
 * Note: This may or may not prevent the registration finished event and registration
 * delegate calls.
 */
- (void)cancelAllRequests;

@end

