/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@class UANotificationAction;

NS_ASSUME_NONNULL_BEGIN

/**
 * Category options for UANotificationCategory. All options only affects iOS 10+.
 */
typedef NS_OPTIONS(NSUInteger, UANotificationCategoryOptions) {
    /**
     * No options.
     */
    UANotificationCategoryOptionNone = (0),

    /**
     * Category will notify the app on dismissal.
     */
    UANotificationCategoryOptionCustomDismissAction = (1 << 0),

    /**
     * Category is allowed in Car Play.
     */
    UANotificationCategoryOptionAllowInCarPlay = (2 << 0),
};


/**
 * Clone of UNNotificationCategory for iOS 8-9 support.
 */
@interface UANotificationCategory : NSObject

///---------------------------------------------------------------------------------------
/// @name Notification Category Properties
///---------------------------------------------------------------------------------------

/**
 * The name of the action group.
 */
@property(readonly, copy, nonatomic) NSString *identifier;

/**
 * The actions to display when a notification of this type is presented.
 */
@property(readonly, copy, nonatomic) NSArray<UANotificationAction *> *actions;

/**
 * The intents supported by notifications of this category.
 *
 * Note: This property is only applicable on iOS 10 and above.
 */
@property(readonly, copy, nonatomic) NSArray<NSString *> *intentIdentifiers;

/**
 * Options for how to handle notifications of this type.
 */
@property(readonly, assign, nonatomic) UANotificationCategoryOptions options;

///---------------------------------------------------------------------------------------
/// @name Notification Category Factories
///---------------------------------------------------------------------------------------

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                               options:(UANotificationCategoryOptions)options;
@end

NS_ASSUME_NONNULL_END
