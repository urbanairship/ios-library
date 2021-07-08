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
 * The tag changes for this request.
 */
@property (nonatomic, copy, nullable) NSDictionary *tagChanges;

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


/**
 * The UAChannelRegistrationPayload as JSON data.
 * @return The payload as JSON data.
 */
- (NSData *)asJSONData;

/**
 * Factory method that builds a payload from NSData.
 * @return A UAChannelRegistrationPayload instance.
 */
+ (UAChannelRegistrationPayload *)channelRegistrationPayloadWithData:(NSData *)data;

/**
 * Returns a Boolean value that indicates whether the contents of the receiving
 * payload are equal to the contents of another given payload.
 * @param payload The payload to compare with.
 * @return YES if the contents of the payload are equal to the contents of the
 *         receiving payload, otherwise NO.
 */
- (BOOL)isEqualToPayload:(nullable UAChannelRegistrationPayload *)payload;

/**
 * The UAChannelRegistrationPayload as an NSDictionary.
 * @return The payload as an NSDictionary.
 */
- (NSDictionary *)payloadDictionary;

/**
 * Creates a new payload with the minimal amount required and optional data for an update.
 * @param lastPayload The last payload.
 * @return The minimal update payload.
 */
- (UAChannelRegistrationPayload *)minimalUpdatePayloadWithLastPayload:(nullable UAChannelRegistrationPayload *)lastPayload;


@end

NS_ASSUME_NONNULL_END
