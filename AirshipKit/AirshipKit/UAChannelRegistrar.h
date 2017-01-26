/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

NS_ASSUME_NONNULL_BEGIN

/**
 * The UAChannelRegistrarDelegate protocol for registration events.
 */
@protocol UAChannelRegistrarDelegate <NSObject>
@optional

/**
 * Called when the channel registrar failed to register.
 * @param payload The registration payload.
 */
- (void)registrationFailedWithPayload:(UAChannelRegistrationPayload *)payload;

/**
 * Called when the channel registrar successfully registered.
 * @param payload The registration payload.
 */
- (void)registrationSucceededWithPayload:(UAChannelRegistrationPayload *)payload;

/**
 * Called when the channel registrar creates a new channel.
 * @param channelID The channel ID string.
 * @param channelLocation The channel location string.
 * @param existing Boolean to indicate if the channel previously existed or not.
 */
- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
              existing:(BOOL)existing;

@end

/**
 * The UAChannelRegistrar class is responsible for device registrations.
 */
@interface UAChannelRegistrar : NSObject

/**
 * A UAChannelRegistrarDelegate delegate.
 */
@property (nonatomic, weak, nullable) id<UAChannelRegistrarDelegate> delegate;

/**
 * Register the device with Urban Airship.
 *
 * @param channelID The channel ID to update.  If `nil` is supplied, a channel will be created.
 * @param channelLocation The channel location.  If `nil` is supplied, a channel will be created.
 * @param payload The payload for the registration.
 * @param forcefully To force the registration, skipping duplicate request checks.
 */
- (void)registerWithChannelID:(nullable NSString *)channelID
              channelLocation:(nullable NSString *)channelLocation
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

NS_ASSUME_NONNULL_END

