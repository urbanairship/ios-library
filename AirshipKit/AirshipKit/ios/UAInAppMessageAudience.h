/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAInAppMessageTagSelector;
@class UAVersionMatcher;
@class UAJSONPredicate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Audience check miss behaviors
 */
typedef NS_ENUM(NSInteger, UAInAppMessageAudienceMissBehaviorType) {
    /**
     * Cancel the message's schedule when the audience check fails.
     */
    UAInAppMessageAudienceMissBehaviorCancel,
    
    /**
     * Skip the message's schedule when the audience check fails.
     */
    UAInAppMessageAudienceMissBehaviorSkip,

    /**
     * Skip and penalize the message's schedule when the audience check fails.
     */
    UAInAppMessageAudienceMissBehaviorPenalize,
};

/**
 * Builder class for UAInAppMessageAudience.
 */
@interface UAInAppMessageAudienceBuilder : NSObject

/**
 * The notifications opt in flag.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) NSNumber *notificationsOptIn;

/**
 * The location opt in flag.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) NSNumber *locationOptIn;

/**
 * The language tags.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSArray<NSString *> *languageTags;

/**
 * The tag selector.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTagSelector *tagSelector;

/**
 * The app version predicate.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAJSONPredicate *versionPredicate;

/**
 * The audience check miss behavior.
 *
 * Optional. Defaults to UAInAppMessageAudienceMissBehaviorPenalize.
 */
@property(nonatomic, assign) UAInAppMessageAudienceMissBehaviorType missBehavior;

/**
 * Checks if the builder is valid and will produce a audience.
 * @return YES if the builder is valid, otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Model object for an in-app message audience constraint.
 *
 * @note This object is built using `UAInAppMessageAudienceBuilder`.
 */
@interface UAInAppMessageAudience : NSObject

/**
 * The notifications opt in flag.
 */
@property(nonatomic, readonly, nullable) NSNumber *notificationsOptIn;

/**
 * The location opt in flag.
 */
@property(nonatomic, readonly, nullable) NSNumber *locationOptIn;

/**
 * The language tags.
 */
@property(nonatomic, readonly, nullable) NSArray<NSString *> *languageIDs;

/**
 * The tag selector
 */
@property(nonatomic, readonly, nullable) UAInAppMessageTagSelector *tagSelector;

/**
 * The app version predicate.
 */
@property(nonatomic, readonly, nullable) UAJSONPredicate *versionPredicate;

/**
 * The audience check miss behavior.
 */
@property(nonatomic, readonly) UAInAppMessageAudienceMissBehaviorType missBehavior;

/**
 * Factory method for building audience model from a builder block.
 *
 * @param builderBlock The builder block.
 * @returns `YES` if the builderBlock was able to be applied, otherwise `NO`.
 */
+ (nullable instancetype)audienceWithBuilderBlock:(void(^)(UAInAppMessageAudienceBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

