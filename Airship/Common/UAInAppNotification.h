
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * Enumeration of in-app notification screen positions.
 */
typedef NS_ENUM(NSInteger, UAInAppNotificationPosition) {
    /**
     * The top of the screen.
     */
    UAInAppNotificationPositionTop,
    /**
     * The bottom of the screen.
     */
    UAInAppNotificationPositionBottom
};

/**
 * Enumeration of in-app notification display types.
 */
typedef NS_ENUM(NSInteger, UAInAppNotificationDisplayType) {
    /**
     * Unknown or unsupported display type.
     */
    UAInAppNotificationDisplayTypeUnknown,
    /**
     * Banner display type.
     */
    UAInAppNotificationDisplayTypeBanner
};

/**
 * Model object representing in-app notification data.
 */
@interface UAInAppNotification : NSObject

/**
 * Class factory method for constructing an unconfigured
 * in-app notification model.
 *
 * @return An unconfigured instance of UAInAppNotification.
 */
+ (instancetype)notification;

/**
 * Class factory method for construction an in-app notification
 * model from the in-app notification section of a push payload.
 *
 * @param payload The in-app notification section of a push payload,
 * in NSDictionary representation.
 * @return A fully configured instance of UAInAppNotification.
 */
+ (instancetype)notificationWithPayload:(NSDictionary *)payload;

/**
 * Retrieves the most recent pending notification from disk.
 *
 * @return An instance of UAInAppNotification, or nil if no
 * pending notification is available.
 */
+ (instancetype)pendingNotification;

/**
 * Stores a pending notification for later retrieval and display.
 *
 * @param payload The in-app notification section of a push payload,
 * in NSDictionary representation.
 */
+ (void)storePendingNotificationPayload:(NSDictionary *)payload;

/**
 * Tests whether the notification is equal by value to another notification.
 *
 * @param notification The notification the receiver is being compared to.
 * @return `YES` if the two notifications are equal by value, `NO` otherwise.
 */
- (BOOL)isEqualToNotification:(UAInAppNotification *)notification;

/**
 * The in-app notification payload in NSDictionary format
 */
@property(nonatomic, readonly) NSDictionary *payload;

/**
 * The unique identifier for the notification (to be set from the associated send id)
 */
@property(nonatomic, copy) NSString *identifier;

// Top level

/**
 * The expiration date for the notification.
 * Unless otherwise specified, defaults to 30 days from construction.
 */
@property(nonatomic, strong) NSDate *expiry;

/**
 * Optional key value extras.
 */
@property(nonatomic, copy) NSDictionary *extra;

// Display

/**
 * The display type. Defaults to `UAInAppNotificationDisplayTypeBanner`
 * when built with the default class constructor, or `UAInAppNotificationDisplayTypeUnknown`
 * when built from a payload with a missing or unidentified display type.
 */
@property(nonatomic, assign) UAInAppNotificationDisplayType displayType;

/**
 * The alert message.
 */
@property(nonatomic, copy) NSString *alert;

/**
 * The screen position. Defaults to `UAInAppNotificationPositionBottom`.
 */
@property(nonatomic, assign) UAInAppNotificationPosition position;

/**
 * The amount of time to wait before automatically dismissing
 * the notification.
 */
@property(nonatomic, assign) NSTimeInterval duration;

/**
 * The primary color.
 */
@property(nonatomic, strong) UIColor *primaryColor;

/**
 * The secondary color.
 */
@property(nonatomic, strong) UIColor *secondaryColor;


// Actions

/**
 * The button group (category) associated with the notification.
 * This value will determine which buttons are present and their
 * localized titles.
 */
@property(nonatomic, copy) NSString *buttonGroup;

/**
 * A dictionary mapping button group keys to dictionaries
 * mapping action names to action arguments. The relevant
 * action(s) will be run when the user taps the associated
 * button.
 */
@property(nonatomic, copy) NSDictionary *buttonActions;

/**
 * A dictionary mapping an action name to an action argument.
 * The relevant action will be run when the user taps or "clicks"
 * on the notification.
 */
@property(nonatomic, copy) NSDictionary *onClick;

@end
