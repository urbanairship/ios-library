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
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Clone of UNNotificationActionOptions for iOS 8-10 support.
 */
typedef NS_OPTIONS(NSUInteger, UANotificationActionOptions) {

    /**
     * Requires the device to be unlocked.
     */
    UANotificationActionOptionAuthenticationRequired = (1 << 0),

    /**
     * Marks the action as destructive.
     */
    UANotificationActionOptionDestructive = (1 << 1),

    /**
     * Causes the action to launch the application.
     */
    UANotificationActionOptionForeground = (1 << 2),
};

static const UANotificationActionOptions UANotificationActionOptionNone NS_SWIFT_UNAVAILABLE("Use [] instead.");

/**
 * Clone of UNNotificationAction for iOS 8-10 support.
 */
@interface UANotificationAction : NSObject


/**
 * The string that you use internally to identify the action.
 */
@property(nonatomic, copy, readonly) NSString *identifier;

/**
 * The localized string to use as the button title for the action.
 */
@property(nonatomic, copy, readonly) NSString *title;

/**
 * The options with which to perform the action.
 */
@property(assign, readonly, nonatomic) UANotificationActionOptions options;

/**
 * Init method.
 *
 * @param identifier The action's identifier.
 * @param title The action's title.
 * @param options The action's options.
 */
- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                           options:(UANotificationActionOptions)options;

/**
 * Creates an action with the specified title and options.
 * 
 * @param identifier The unique string that you use internally to identify the action. 
 *        When the user selects the action, the system passes this string to your
 *        app and asks you to perform the related task. This parameter must not be nil.
 * @param title The localized string to display to the user.
 *        This string is displayed in interface elements such as buttons that are
 *        used to represent actions. This parameter must not be nil.
 * @param options Additional options for how the action should be performed. Add options
 *        sparingly and only when you require the related behavior. For a list of
 *        possible values, see UANotificationActionOptions.
 */
+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                             options:(UANotificationActionOptions)options;
/**
 * Converts a UANotificationAction into a UIUserNotificationAction.
 *
 * @return An instance of UIUserNotificationAction or nil if conversion fails.
 */
- (nullable UIUserNotificationAction *)asUIUserNotificationAction;

/**
 * Converts a UANotificationAction into a UNNotificationAction.
 *
 * @return An instance of UNUNotificationAction or nil if conversion fails.
 */
- (nullable UNNotificationAction *)asUNNotificationAction __IOS_AVAILABLE(10.0);

@end

NS_ASSUME_NONNULL_END
