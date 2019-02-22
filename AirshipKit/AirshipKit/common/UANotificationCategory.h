/* Copyright Urban Airship and Contributors */

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
     * Category will notify the app on dismissal.
     */
    UANotificationCategoryOptionCustomDismissAction = (1 << 0),

    /**
     * Category is allowed in Car Play.
     */
    UANotificationCategoryOptionAllowInCarPlay = (2 << 0),
};

static const UANotificationCategoryOptions UANotificationCategoryOptionNone NS_SWIFT_UNAVAILABLE("Use [] instead.") = 0;


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
 * A placeholder string to display when the user has disabled notification previews for the app.
 *
 * Note: This property is only applicable on iOS 11 and above.
 */
@property(readonly, copy, nonatomic, nullable) NSString *hiddenPreviewsBodyPlaceholder;

/**
 * A format string for a summary description when notifications from this category are grouped together.
 *
 * Note: This property is only applicable on iOS 12 and above.
 */
@property (readonly, nonatomic, nullable) NSString *categorySummaryFormat;

/**
 * Options for how to handle notifications of this type.
 */
@property(readonly, assign, nonatomic) UANotificationCategoryOptions options;

///---------------------------------------------------------------------------------------
/// @name Notification Category Factories
///---------------------------------------------------------------------------------------

/**
 * Creates a user notification category with the specified parameters.
 *
 * @param identifier The category identifier
 * @param actions An array of user notification actions
 * @param intentIdentifiers The intents supported for notifications of this category.
 * @param options Constants indicating how to handle notifications associated with this category.
 * @return The user notification category created or `nil` if an error occurred.
 */
+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                               options:(UANotificationCategoryOptions)options;

/**
 * Creates a user notification category with the specified parameters.
 *
 * @param identifier The category identifier
 * @param actions An array of user notification actions
 * @param intentIdentifiers The intents supported for notifications of this category.
 * @param hiddenPreviewsBodyPlaceholder A placeholder string to display when the user has disabled
          notification previews for the app.
 * @param options Constants indicating how to handle notifications associated with this category.
 * @return The user notification category created or `nil` if an error occurred.
 */
+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
         hiddenPreviewsBodyPlaceholder:(nullable NSString *)hiddenPreviewsBodyPlaceholder
                               options:(UANotificationCategoryOptions)options;

/**
 * Creates a user notification category with the specified parameters.
 *
 * @param identifier The category identifier
 * @param actions An array of user notification actions
 * @param intentIdentifiers The intents supported for notifications of this category.
 * @param hiddenPreviewsBodyPlaceholder A placeholder string to display when the user has disabled
 notification previews for the app.
 * @param format A format string for a summary description when notifications from this
 category are grouped together
 * @param options Constants indicating how to handle notifications associated with this category.
 * @return The user notification category created or `nil` if an error occurred.
 */
+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
         hiddenPreviewsBodyPlaceholder:(nullable NSString *)hiddenPreviewsBodyPlaceholder
                 categorySummaryFormat:(nullable NSString *)format
                               options:(UANotificationCategoryOptions)options;

///---------------------------------------------------------------------------------------
/// @name Notification Category Utilities
///---------------------------------------------------------------------------------------

#if TARGET_OS_IOS // UNNotificationAction not available on tvOS
/**
 * Converts a UANotificationCategory into a UNNotificationCategory.
 *
 * @return An instance of UNNotificationCategory.
 */
- (null_unspecified UNNotificationCategory *)asUNNotificationCategory;

/**
 * Tests for equivalence with a UNNotificationCategory.
 *
 * @param category The UNNotificationCategory to compare with.
 * @return `YES` if the two categories are equivalent, `NO` otherwise.
 */
- (BOOL)isEqualToUNNotificationCategory:(UNNotificationCategory *)category;

#endif


@end

NS_ASSUME_NONNULL_END
