/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
#import <UIKit/UIKit.h>

@class UAInAppMessage;

/**
 * Delegate protocol for receiving in-app messaging related
 * callbacks.
 */
@protocol UAInAppMessagingDelegate <NSObject>

@optional

/**
 * Indicates that an in-app message has been stored as pending.
 * @param message The associated in-app message.
 */
- (void)pendingMessageAvailable:(UAInAppMessage *)message;

/**
 * Indicates that an in-app message will be automatically displayed.
 * @param message The associated in-app message.
 */
- (void)messageWillBeDisplayed:(UAInAppMessage *)message;

@end


@interface UAInAppMessaging : NSObject

/**
* Retrieves the most recent pending message payload from disk.
*
* @return An in-app message payload in NSDictionary format.
*/
- (NSDictionary *)pendingMessagePayload;

/**
 * Stores a pending message for later retrieval and display.
 *
 * @param message An in-app message instance.
 */
- (void)storePendingMessage:(UAInAppMessage *)message;

/**
 * Deletes the pending message payload if present.
 *
 */
- (void)deletePendingMessagePayload;

/**
 * Deletes the pending message if it matches the
 * provided message argument.
 *
 * @param message The message to delete.
 */
- (void)deletePendingMessage:(UAInAppMessage *)message;

/**
 * Displays the the provided message. If the message is expired,
 * or if it was associated with the notification that launched the app,
 * this will be a no-op.
 *
 * @param message The message to display.
 */
- (void)displayMessage:(UAInAppMessage *)message;

/**
 * The desired font to use when displaying in-app messages.
 * Defaults to a bold system font 12 points in size.
 */
@property(nonatomic, strong) UIFont *font;

/**
 * An optional delegate to receive in-app messaging related callbacks.
 */
@property(nonatomic, weak) id<UAInAppMessagingDelegate> delegate;

@end
