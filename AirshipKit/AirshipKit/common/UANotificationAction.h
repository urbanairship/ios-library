/* Copyright 2017 Urban Airship and Contributors */

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

///---------------------------------------------------------------------------------------
/// @name Notification Action Properties
///---------------------------------------------------------------------------------------

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

///---------------------------------------------------------------------------------------
/// @name Notification Action Initialization
///---------------------------------------------------------------------------------------

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

///---------------------------------------------------------------------------------------
/// @name Notification Action Utilities
///---------------------------------------------------------------------------------------

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
