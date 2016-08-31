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

/**
 * Enumeration of in-app message screen positions.
 */
typedef NS_ENUM(NSInteger, UAInAppMessagePosition) {
    /**
     * The top of the screen.
     */
    UAInAppMessagePositionTop,
    /**
     * The bottom of the screen.
     */
    UAInAppMessagePositionBottom
};

/**
 * Enumeration of in-app message display types.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageDisplayType) {
    /**
     * Unknown or unsupported display type.
     */
    UAInAppMessageDisplayTypeUnknown,
    /**
     * Banner display type.
     */
    UAInAppMessageDisplayTypeBanner
};

@class UAInAppMessageButtonActionBinding;
@class UANotificationCategory;

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object representing in-app message data.
 */
@interface UAInAppMessage : NSObject

/**
 * Class factory method for constructing an unconfigured
 * in-app message model.
 *
 * @return An unconfigured instance of UAInAppMessage.
 */
+ (instancetype)message;

/**
 * Class factory method for constructing an in-app message
 * model from the in-app message section of a push payload.
 *
 * @param payload The in-app message section of a push payload,
 * in NSDictionary representation.
 * @return A fully configured instance of UAInAppMessage.
 */
+ (instancetype)messageWithPayload:(NSDictionary *)payload;

/**
 * Tests whether the message is equal by value to another message.
 *
 * @param message The message the receiver is being compared to.
 * @return `YES` if the two messages are equal by value, `NO` otherwise.
 */
- (BOOL)isEqualToMessage:(nullable UAInAppMessage *)message;

/**
 * The in-app message payload in NSDictionary format
 */
@property(nonatomic, readonly) NSDictionary *payload;

/**
 * The unique identifier for the message (to be set from the associated send ID)
 */
@property(nonatomic, copy, nullable) NSString *identifier;

// Top level

/**
 * The expiration date for the message.
 * Unless otherwise specified, defaults to 30 days from construction.
 */
@property(nonatomic, strong) NSDate *expiry;

/**
 * Optional key value extras.
 */
@property(nonatomic, copy, nullable) NSDictionary *extra;

// Display

/**
 * The display type. Defaults to `UAInAppMessageDisplayTypeBanner`
 * when built with the default class constructor, or `UAInAppMessageDisplayTypeUnknown`
 * when built from a payload with a missing or unidentified display type.
 */
@property(nonatomic, assign) UAInAppMessageDisplayType displayType;

/**
 * The alert message.
 */
@property(nonatomic, copy, nullable) NSString *alert;

/**
 * The screen position. Defaults to `UAInAppMessagePositionBottom`.
 */
@property(nonatomic, assign) UAInAppMessagePosition position;

/**
 * The amount of time to wait before automatically dismissing
 * the message.
 */
@property(nonatomic, assign) NSTimeInterval duration;

/**
 * The primary color.
 */
@property(nonatomic, strong, nullable) UIColor *primaryColor;

/**
 * The secondary color.
 */
@property(nonatomic, strong, nullable) UIColor *secondaryColor;


// Actions

/**
 * The button group (category) associated with the message.
 * This value will determine which buttons are present and their
 * localized titles.
 */
@property(nonatomic, copy, nullable) NSString *buttonGroup;

/**
 * A dictionary mapping button group keys to dictionaries
 * mapping action names to action arguments. The relevant
 * action(s) will be run when the user taps the associated
 * button.
 */
@property(nonatomic, copy, nullable) NSDictionary *buttonActions;

/**
 * A dictionary mapping an action name to an action argument.
 * The relevant action will be run when the user taps or "clicks"
 * on the message.
 */
@property(nonatomic, copy, nullable) NSDictionary *onClick;

/**
 * The chosen notification action context. If there are notification actions defined for
 * UIUserNotificationActionContextMinimal, this context will be preferred. Othwerise, the
 * context defaults to UIUserNotificationActionContextDefault.
 */
@property(nonatomic, readonly) UIUserNotificationActionContext notificationActionContext;

/**
 * An array of UNNotificationAction instances corresponding to the left-to-right order
 * of interactive message buttons.
 */
@property(nonatomic, readonly, nullable) NSArray *notificationActions;

/**
 * A UANotificationCategory instance,
 * corresponding to the button group of the message.
 * If no matching category is found, this property will be nil.
 */
@property(nonatomic, readonly, nullable) UANotificationCategory *buttonCategory;

/**
 * An array of UAInAppMessageButtonActionBinding instances,
 * corresponding to the left-to-right order of interactive message
 * buttons.
 */
@property(nonatomic, readonly, nullable) NSArray *buttonActionBindings;

@end

NS_ASSUME_NONNULL_END

