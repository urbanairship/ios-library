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

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;
@class UAConfig;

/**
 * The UADefaultMessageCenter class provides a default implementation of a
 * message center, as well as a high-level interface for its configuration and display.
 */
@interface UADefaultMessageCenter : NSObject


/**
 * The title of the message center.
 */
@property (nonatomic, strong) NSString *title;

/**
 * The style to apply to the default message center.
 */
@property (nonatomic, strong) UADefaultMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;


/**
 * Factory method for creating message center with style specified in a config.
 *
 * @return A Message Center instance initialized with the style specified in the provided config.
 */
+ (instancetype)messageCenterWithConfig:(UAConfig *)config;

/**
 * Display the message center.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)display:(BOOL)animated;

/**
 * Display the message center with animation.
 */
- (void)display;

/**
 * Display the given message.
 *
 * @param message The message.
 * @param animated Whether the transition should be animated.
 */
- (void)displayMessage:(UAInboxMessage *)message animated:(BOOL)animated;

/**
 * Display the given message without animation.
 *
 * @pararm message The message.
 */
- (void)displayMessage:(UAInboxMessage *)message;

/**
 * Dismiss the message center.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)dismiss:(BOOL)animated;

/**
 * Dismiss the message center with animation.
 */
- (void)dismiss;

@end
