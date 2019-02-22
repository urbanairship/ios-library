/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageAudience.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing audience from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageAudienceErrorCode) {
    /**
     * Indicates an error with the tag selector JSON definition.
     */
    UAInAppMessageAudienceErrorCodeInvalidJSON,
};

@interface UAInAppMessageAudienceBuilder()

/**
 * The new user flag.
 *
 * Optional. Defaults to "NO".
 */
@property(nonatomic, strong, nullable) NSNumber *isNewUser;

/**
 * Test devices.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSArray<NSString *> *testDevices;

@end

@interface UAInAppMessageAudience()

/**
 * The new user flag.
 */
@property(nonatomic, nullable, readonly) NSNumber *isNewUser;

/**
 * Test devices.
 */
@property(nonatomic, nullable, readonly) NSArray<NSString *> *testDevices;

/**
 * Factory method for building audience model from JSON.
 *
 * @param json The json object.
 * @param error An NSError pointer for storing errors, if applicable.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
+ (nullable instancetype)audienceWithJSON:(id)json error:(NSError **)error;

/**
 * Method to return the audience as its JSON representation.
 *
 * @returns JSON representation of audience (as NSDictionary)
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
