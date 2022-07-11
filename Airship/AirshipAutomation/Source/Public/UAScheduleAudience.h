/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UATagSelector;
@class UAVersionMatcher;
@class UAJSONPredicate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Audience check miss behaviors
 */
typedef NS_ENUM(NSInteger, UAScheduleAudienceMissBehaviorType) {
    /**
     * Cancel the message's schedule when the audience check fails.
     */
    UAScheduleAudienceMissBehaviorCancel,
    
    /**
     * Skip the message's schedule when the audience check fails.
     */
    UAScheduleAudienceMissBehaviorSkip,

    /**
     * Skip and penalize the message's schedule when the audience check fails.
     */
    UAScheduleAudienceMissBehaviorPenalize,
} NS_SWIFT_NAME(ScheduleAudienceMissBehaviorType);

/**
 * Builder class for UAScheduleAudience.
 */
NS_SWIFT_NAME(ScheduleAudienceBuilder)
@interface UAScheduleAudienceBuilder : NSObject

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
@property(nonatomic, strong, nullable) UATagSelector *tagSelector;

/**
 * The app version predicate.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAJSONPredicate *versionPredicate;

/**
 * The audience check miss behavior.
 *
 * Optional. Defaults to UAScheduleAudienceMissBehaviorPenalize.
 */
@property(nonatomic, assign) UAScheduleAudienceMissBehaviorType missBehavior;

/**
 * The require analytics audience condition for the in-app message.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) NSNumber *requiresAnalytics;

/**
 * The audience permission predicate.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAJSONPredicate *permissionPredicate;

/**
 * Checks if the builder is valid and will produce a audience.
 * @return YES if the builder is valid, otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Model object for an in-app message audience constraint.
 *
 * @note This object is built using `UAScheduleAudienceBuilder`.
 */
NS_SWIFT_NAME(ScheduleAudience)
@interface UAScheduleAudience : NSObject

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
@property(nonatomic, readonly, nullable) UATagSelector *tagSelector;

/**
 * The app version predicate.
 */
@property(nonatomic, readonly, nullable) UAJSONPredicate *versionPredicate;

/**
 * The audience check miss behavior.
 */
@property(nonatomic, readonly) UAScheduleAudienceMissBehaviorType missBehavior;

/**
 * The require analytics audience condition for the in-app message.
 */
@property(nonatomic, readonly, nullable) NSNumber *requiresAnalytics;

/**
 * The audience permission predicate.
 */
@property(nonatomic, readonly, nullable) UAJSONPredicate *permissionPredicate;

/**
 * Factory method for building audience model from a builder block.
 *
 * @param builderBlock The builder block.
 * @returns `YES` if the builderBlock was able to be applied, otherwise `NO`.
 */
+ (nullable instancetype)audienceWithBuilderBlock:(void(^)(UAScheduleAudienceBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

