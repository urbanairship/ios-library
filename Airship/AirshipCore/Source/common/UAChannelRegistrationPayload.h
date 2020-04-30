/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object encapsulating the data relevant for Channel registration.
 * @note For internal use only. :nodoc:
 */
@interface UAChannelRegistrationPayload : NSObject<NSCopying>

///---------------------------------------------------------------------------------------
/// @name Channel Registration Payload Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The user ID.
 */
@property (nonatomic, copy, nullable) NSString *userID;

/**
 * The device ID.
 */
@property (nonatomic, copy, nullable) NSString *deviceID;

/**
 * The Accengage device ID.
 */
@property (nonatomic, copy, nullable) NSString *accengageDeviceID;

/**
 * This flag indicates that the user is able to receive push notifications.
 */
@property (nonatomic, assign, getter=isOptedIn) BOOL optedIn;

/**
 * The address to push notifications to.  This should be the device token.
 */
@property (nonatomic, copy) NSString *pushAddress;

/**
 * The named user identifier.
 */
@property (nonatomic, copy, nullable) NSString *namedUserId;

/**
 * The flag indicates tags in this request should be handled.
 */
@property (nonatomic, assign) BOOL setTags;

/**
 * The tags for this device.
 */
@property (nonatomic, copy, nullable) NSArray<NSString *> *tags;

/**
 * Quiet time settings for this device.
 */
@property (nonatomic, copy, nullable) NSDictionary *quietTime;

/**
 * Quiet time time zone.
 */
@property (nonatomic, copy, nullable) NSString *quietTimeTimeZone;

/**
 * The locale language for this device.
 */
@property (nonatomic, copy, nullable) NSString *language;

/**
 * The locale country for this device.
 */
@property (nonatomic, copy, nullable) NSString *country;

/**
 * The time zone for this device.
 */
@property (nonatomic, copy, nullable) NSString *timeZone;

/**
 * The badge for this device.
 */
@property (nonatomic, strong, nullable) NSNumber *badge;

/**
 * The location setting for the device.
 */
@property (nonatomic, strong, nullable) NSNumber *locationSettings;

/**
 * The app version.
 */
@property (nonatomic, copy, nullable) NSString *appVersion;

/**
 * The sdk version.
 */
@property (nonatomic, copy, nullable) NSString *SDKVersion;

/**
 * The device model.
 */
@property (nonatomic, copy, nullable) NSString *deviceModel;

/**
 * The device OS.
 */
@property (nonatomic, copy, nullable) NSString *deviceOS;

/**
 * The carrier.
 */
@property (nonatomic, copy, nullable) NSString *carrier;

/**
 * This flag indicates that the user is able to receive background notifications.
 */
@property (nonatomic, assign, getter=isBackgroundEnabled) BOOL backgroundEnabled;

@end

NS_ASSUME_NONNULL_END
