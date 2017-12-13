/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAInAppMessageTagSelector;
@class UAVersionMatcher;

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

/**
 * Builder class for a UAInAppMessageAudience.
 */
@interface UAInAppMessageAudienceBuilder : NSObject

/**
 * The notifications opt in flag.
 */
@property(nonatomic, copy) NSNumber *notificationsOptIn;

/**
 * The location opt in flag.
 */
@property(nonatomic, copy) NSNumber *locationOptIn;

/**
 * The language tags.
 */
@property(nonatomic, strong, nullable) NSArray<NSString *> *languageTags;

/**
 * The tag selector
 */
@property(nonatomic, strong, nullable) UAInAppMessageTagSelector *tagSelector;

/**
 * The app version predicate
 */
@property(nonatomic, strong, nullable) UAVersionMatcher *versionMatcher;

@end

/**
 * Model object for an In App Message audience constraint.
 */
@interface UAInAppMessageAudience : NSObject

/**
 * The notifications opt in flag.
 */
@property(nonatomic, strong) NSNumber *notificationsOptIn;

/**
 * The location opt in flag.
 */
@property(nonatomic, strong) NSNumber *locationOptIn;

/**
 * The language tags.
 */
@property(nonatomic, strong, nullable) NSArray<NSString *> *languageIDs;

/**
 * The tag selector
 */
@property(nonatomic, strong, nullable) UAInAppMessageTagSelector *tagSelector;

/**
 * The app version matcher
 */
@property(nonatomic, strong, nullable) UAVersionMatcher *versionMatcher;

/**
 * Factory method for building audience model from JSON.
 *
 * @param json The json object.
 * @param error An NSError pointer for storing errors, if applicable.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
+ (instancetype)audienceWithJSON:(id)json error:(NSError **)error;

/**
 * Factory method for building audience model from a builder block.
 *
 * @param builderBlock The builder block.
 * @returns `YES` if the builderBlock was able to be applied, otherwise `NO`.
 */
+ (instancetype)audienceWithBuilderBlock:(void(^)(UAInAppMessageAudienceBuilder *builder))builderBlock;

/**
 * Method to return the audience as its JSON representation.
 *
 * @returns JSON representation of audience (as NSDictionary)
 */
- (NSDictionary *)toJsonValue;

@end

NS_ASSUME_NONNULL_END

