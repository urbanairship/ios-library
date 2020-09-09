/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for bridging push provider functionality with the SDK.
 */
@protocol UAPushProviderDelegate <NSObject>

/**
 * Enables/disables sending the device token during channel registration.
 */
@property (nonatomic, assign) BOOL pushTokenRegistrationEnabled;

/**
 * Returns YES if user notifications are configured and enabled for the device.
 */
@property (nonatomic, readonly) BOOL userPushNotificationsAllowed;

/**
 * Returns YES if background push is enabled and configured for the device. Used
 * as the channel's 'background' flag.
 */
@property (nonatomic, readonly) BOOL backgroundPushNotificationsAllowed;

/**
 * Toggle the Airship auto-badge feature.
 */
@property (nonatomic, assign, getter=isAutobadgeEnabled) BOOL autobadgeEnabled;

/**
 * The current badge number used by the device and on the Airship server.
 */
@property (nonatomic, assign) NSInteger badgeNumber;

/**
 * Enables/Disables quiet time
 */
@property (nonatomic, assign, getter=isQuietTimeEnabled) BOOL quietTimeEnabled;

/**
 *  Quiet time settings for this device.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary *quietTime;

/**
 * Time Zone for quiet time.
 */
@property (nonatomic, strong) NSTimeZone *timeZone;

/**
 * The device token for this device, as a hex string.
 */
@property (nonatomic, copy, readonly, nullable) NSString *deviceToken;

@end

NS_ASSUME_NONNULL_END
