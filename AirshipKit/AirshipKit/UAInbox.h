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

#import "UAGlobal.h"

@class UAInboxMessageList;
@class UAInboxAPIClient;
@class UAInboxMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving callbacks related to
 * Rich Push message delivery and display.
 */
@protocol UAInboxDelegate <NSObject>

@optional

/**
 * Called when the UADisplayInboxAction was triggered from a foreground notification.
 *
 * @param richPushMessage The Rich Push message
 */
- (void)richPushMessageAvailable:(UAInboxMessage *)richPushMessage;

/**
 * Called when the inbox is requested to be displayed by the UADisplayInboxAction.
 *
 * @param message The Rich Push message
 */
- (void)showInboxMessage:(UAInboxMessage *)message;

@required

/**
 * Called when the inbox is requested to be displayed by the UADisplayInboxAction.
 */
- (void)showInbox;

@end

/**
 * The main class for interacting with the Rich Push Inbox.
 *
 * This class bridges library functionality with the UI and is the main point of interaction.
 * Most implementations will only use functionality found in this class.
 */
@interface UAInbox : NSObject

/**
 * The list of Rich Push Inbox messages.
 */
@property (nonatomic, strong) UAInboxMessageList *messageList;

/**
 * The Inbox API Client
 */
@property (nonatomic, readonly, strong) UAInboxAPIClient *client;


/**
 * The delegate that should be notified when an incoming push is handled,
 * as an object conforming to the UAInboxDelegate protocol.
 * NOTE: The delegate is not retained.
 */
@property (nonatomic, weak, nullable) id <UAInboxDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
