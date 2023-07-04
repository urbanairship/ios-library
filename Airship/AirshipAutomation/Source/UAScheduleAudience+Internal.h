/* Copyright Airship and Contributors */

#import "UAScheduleAudience.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing audience from JSON.
 */
typedef NS_ENUM(NSInteger, UAScheduleAudienceErrorCode) {
    /**
     * Indicates an error with the tag selector JSON definition.
     */
    UAScheduleAudienceErrorCodeInvalidJSON,
};

@interface UAScheduleAudience()

/**
 * Factory method for building audience model from JSON.
 *
 * @param json The json object.
 * @param error An NSError pointer for storing errors, if applicable.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
+ (nullable instancetype)audienceWithJSON:(id)json error:(NSError **)error;

/**
 * Parses the miss behavior.
 *
 * @param json The json object.
 * @param error An NSError pointer for storing errors, if applicable.
 * @returns The miss behavior or peanlize if not able to be parsed.
 */
+ (UAScheduleAudienceMissBehaviorType)parseMissBehavior:(id)json error:(NSError **)error;

/**
 * Method to return the audience as its JSON representation.
 *
 * @returns JSON representation of audience (as NSDictionary)
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
