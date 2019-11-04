/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAChannelIdentityHintsKey;
extern NSString *const UAChannelUserIDKey;
extern NSString *const UAChannelDeviceIDKey;

extern NSString *const UAChannelKey;
extern NSString *const UAChannelDeviceTypeKey;
extern NSString *const UAChannelOptInKey;
extern NSString *const UAChannelPushAddressKey;

extern NSString *const UAChannelTopLevelTimeZoneJSONKey;
extern NSString *const UAChannelTopLevelLanguageJSONKey;
extern NSString *const UAChannelTopLevelCountryJSONKey;
extern NSString *const UAChannelTopLevelLocationSettingsJSONKey;
extern NSString *const UAChannelTopLevelAppVersionJSONKey;
extern NSString *const UAChannelTopLevelSDKVersionJSONKey;
extern NSString *const UAChannelTopLevelDeviceModelJSONKey;
extern NSString *const UAChannelTopLevelDeviceOSJSONKey;
extern NSString *const UAChannelTopLevelCarrierJSONKey;

extern NSString *const UAChannelIOSKey;
extern NSString *const UAChannelBadgeJSONKey;
extern NSString *const UAChannelQuietTimeJSONKey;
extern NSString *const UAChannelTimeZoneJSONKey;

extern NSString *const UAChannelAliasJSONKey;
extern NSString *const UAChannelSetTagsKey;
extern NSString *const UAChannelTagsJSONKey;

extern NSString *const UABackgroundEnabledJSONKey;

/**
 * Model object encapsulating the data relevant to a creation or updates processed by UAChannelAPIClient.
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
 * This flag indicates that the user is able to receive push notifications.
 */
@property (nonatomic, assign, getter=isOptedIn) BOOL optedIn;

/**
 * The address to push notifications to.  This should be the device token.
 */
@property (nonatomic, copy) NSString *pushAddress;

/**
 * The flag indicates tags in this request should be handled.
 */
@property (nonatomic, assign) BOOL setTags;

/**
 * The tags for this device.
 */
@property (nonatomic, strong, nullable) NSArray<NSString *> *tags;

/**
 * Quiet time time zone.
 */
@property (nonatomic, copy, nullable) NSString *quietTimeTimeZone;

/**
 * Quiet time settings for this device.
 */
@property (nonatomic, strong, nullable) NSDictionary *quietTime;

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


///---------------------------------------------------------------------------------------
/// @name Channel Registration Payload Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method that builds a payload from NSData.
 * @return A UAChannelRegistrationPayload instance.
 */
+ (UAChannelRegistrationPayload *)channelRegistrationPayloadWithData:(NSData *)data;

/**
 * The UAChannelRegistrationPayload as JSON data.
 * @return The payload as JSON data.
 */
- (NSData *)asJSONData;

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
