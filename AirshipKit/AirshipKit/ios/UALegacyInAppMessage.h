/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * Enumeration of in-app message screen positions.
 */
typedef NS_ENUM(NSInteger, UALegacyInAppMessagePosition) {
    /**
     * The top of the screen.
     */
    UALegacyInAppMessagePositionTop,
    /**
     * The bottom of the screen.
     */
    UALegacyInAppMessagePositionBottom
};

/**
 * Enumeration of in-app message display types.
 */
typedef NS_ENUM(NSInteger, UALegacyInAppMessageDisplayType) {
    /**
     * Banner display type.
     */
    UALegacyInAppMessageDisplayTypeBanner
};

@class UALegacyInAppMessageButtonActionBinding;
@class UANotificationCategory;

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object representing in-app message data.
 */
@interface UALegacyInAppMessage : NSObject

///---------------------------------------------------------------------------------------
/// @name Legacy In App Message Properties
///---------------------------------------------------------------------------------------

/**
 * The in-app message payload in NSDictionary format
 */
@property(nonatomic, readonly) NSDictionary *payload;

/**
 * The unique identifier for the message (to be set from the associated send ID)
 */
@property(nonatomic, copy, nullable) NSString *identifier;

///---------------------------------------------------------------------------------------
/// @name Legacy In App Message Top Level Properties
///---------------------------------------------------------------------------------------

/**
 * The expiration date for the message.
 * Unless otherwise specified, defaults to 30 days from construction.
 */
@property(nonatomic, strong) NSDate *expiry;

/**
 * Optional key value extra.
 */
@property(nonatomic, copy, nullable) NSDictionary *extra;

///---------------------------------------------------------------------------------------
/// @name Legacy In App Message Display Properties
///---------------------------------------------------------------------------------------

/**
 * The display type. Defaults to `UALegacyInAppMessageDisplayTypeBanner`
 * when built with the default class constructor.
 * When built from a payload with a missing or unidentified display type,
 * the message will be nil.
 */
@property(nonatomic, assign) UALegacyInAppMessageDisplayType displayType;

/**
 * The alert message.
 */
@property(nonatomic, copy, nullable) NSString *alert;

/**
 * The screen position. Defaults to `UAInAppMessagePositionBottom`.
 */
@property(nonatomic, assign) UALegacyInAppMessagePosition position;

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


///---------------------------------------------------------------------------------------
/// @name Legacy In App Message Actions Properties
///---------------------------------------------------------------------------------------

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


///---------------------------------------------------------------------------------------
/// @name Legacy In App Message Factories
///---------------------------------------------------------------------------------------

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
+ (nullable instancetype)messageWithPayload:(NSDictionary *)payload;

///---------------------------------------------------------------------------------------
/// @name Legacy In App Message Utilities
///---------------------------------------------------------------------------------------

/**
 * Tests whether the message is equal by value to another message.
 *
 * @param message The message the receiver is being compared to.
 * @return `YES` if the two messages are equal by value, `NO` otherwise.
 */
- (BOOL)isEqualToMessage:(nullable UALegacyInAppMessage *)message;

@end

NS_ASSUME_NONNULL_END

