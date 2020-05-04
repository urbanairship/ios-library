/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAChannelRegistrationPayload.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAChannelIdentityHintsKey;
extern NSString *const UAChannelUserIDKey;
extern NSString *const UAChannelDeviceIDKey;

extern NSString *const UAChannelKey;
extern NSString *const UAChannelDeviceTypeKey;
extern NSString *const UAChannelOptInKey;
extern NSString *const UAChannelPushAddressKey;
extern NSString *const UAChannelNamedUserIdKey;

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

@interface UAChannelRegistrationPayload()

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
