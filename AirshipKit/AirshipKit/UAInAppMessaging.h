/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
#import "UAInAppMessageControllerDelegate.h"

@class UAInAppMessage;

NS_ASSUME_NONNULL_BEGIN

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


/**
 * Manager class for in-app messaging.
 */
@interface UAInAppMessaging : NSObject

/**
 * Deletes the pending message if it matches the
 * provided message argument.
 *
 * @param message The message to delete.
 */
- (void)deletePendingMessage:(UAInAppMessage *)message;

/**
 * Displays the provided message. Expired messages will be
 * ignored.
 *
 * @param message The message to display.
 */
- (void)displayMessage:(UAInAppMessage *)message;

/*
 * Displays the pending message if it is available.
 */
- (void)displayPendingMessage;

/**
 * The pending in-app message.
 */
@property(nonatomic, copy, nullable) UAInAppMessage *pendingMessage;

/**
 * Enables/disables auto-display of in-app messages.
 */
@property(nonatomic, assign, getter=isAutoDisplayEnabled) BOOL autoDisplayEnabled;

/**
 * The desired font to use when displaying in-app messages.
 * Defaults to a bold system font 12 points in size.
 */
@property(nonatomic, strong) UIFont *font;

/**
 * The default primary color for messages (background and button color). Colors sent in
 * an in-app message payload will override this setting. Defaults to white.
 */
@property(nonatomic, strong) UIColor *defaultPrimaryColor;

/**
 * The default secondary color for messages (text and border color). Colors sent in
 * an in-app message payload will override this setting. Defaults to gray (#282828).
 */
@property(nonatomic, strong) UIColor *defaultSecondaryColor;

/**
 * The initial delay before displaying an in-app message. The timer begins when the
 * application becomes active. Defaults to 3 seconds.
 */
@property(nonatomic, assign) NSTimeInterval displayDelay;

/**
 * Whether to display an incoming message as soon as possible, as opposed to on app foreground
 * transitions. If set to `YES`, and if automatic display is enabled, when a message arrives in 
 * the foreground it will be automatically displayed as soon as it has been received. Otherwise 
 * the message will be stored as pending. Defaults to `NO`.
 */
@property(nonatomic, assign, getter=isDisplayASAPEnabled) BOOL displayASAPEnabled;

/**
 * An optional delegate to receive in-app messaging related callbacks.
 */
@property(nonatomic, weak, nullable) id<UAInAppMessagingDelegate> messagingDelegate;

/**
 * A optional delegate for configuring and providing custom UI during message display.
 */
@property(nonatomic, weak, nullable) id<UAInAppMessageControllerDelegate> messageControllerDelegate;

@end

NS_ASSUME_NONNULL_END
