/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UNNotification;

/**
 * iOS version-independent wrapper for UNNotificationContent. Contains convenient accessors
 * to the notification's content.
 */
@interface UANotificationContent : NSObject

///---------------------------------------------------------------------------------------
/// @name Notification Content Properties
///---------------------------------------------------------------------------------------

/**
 * Alert title
 */
@property (nonatomic, copy, nullable, readonly) NSString *alertTitle;

/**
 * Alert body
 */
@property (nonatomic, copy, nullable, readonly) NSString *alertBody;

/**
 * Sound file name
 */
@property (nonatomic, copy, nullable, readonly) NSString *sound;

/**
 * Badge number
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *badge;

/**
 * Content available
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *contentAvailable;

/**
 * Summary argument
 */
@property (nonatomic, copy, nullable, readonly) NSString *summaryArgument;

/**
 * Summary argument count
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *summaryArgumentCount;

/**
 * Thread identifier
 */
@property (nonatomic, copy, nullable, readonly) NSString *threadIdentifier;

/**
 * Target content identifier
 */
@property (nonatomic, copy, nullable, readonly) NSString *targetContentIdentifier;

/**
 * Category
 */
@property (nonatomic, copy, nullable, readonly) NSString *categoryIdentifier;

/**
 * Launch image file name
 */
@property (nonatomic, copy, nullable, readonly) NSString *launchImage;

/**
 * Localization keys
 */
@property (nonatomic, copy, nullable, readonly) NSDictionary *localizationKeys;

/**
 * Notification info dictionary used to generate the UANotification.
 */
@property (nonatomic, copy, readonly) NSDictionary *notificationInfo;

/**
 * UNNotification used to generate the UANotification.
 * This will be nil when receiving silent, `content-available` pushes in the background.
 */
@property (nonatomic, strong, nullable, readonly) UNNotification *notification;

///---------------------------------------------------------------------------------------
/// @name Notification Content Utilities
///---------------------------------------------------------------------------------------

/**
 * Parses the raw notification dictionary into a UANotification.
 *
 * @param notificationInfo The raw notification dictionary.
 *
 * @return UANotification instance
 */
+ (instancetype)notificationWithNotificationInfo:(NSDictionary *)notificationInfo;

/**
 * Converts a UNNotification into a UANotification.
 *
 * @param notification the UNNotification instance to be converted.
 *
 * @return UANotification instance
 */
+ (instancetype)notificationWithUNNotification:(UNNotification *)notification;

/**
 * Checks if the notification was sent from Airship.
 *
 * @return YES if it's an Airship notification, otherwise NO.
 */
- (BOOL)isAirshipNotificationContent;

@end

NS_ASSUME_NONNULL_END
