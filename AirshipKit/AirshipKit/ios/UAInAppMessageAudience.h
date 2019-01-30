/* Copyright 2010-2019 Urban Airship and Contributors */

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
 * The tag selector.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTagSelector *tagSelector;

/**
 * The app version predicate.
 */
@property(nonatomic, strong, nullable) UAJSONPredicate *versionPredicate;

/**
 * The audience check miss behavior.
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
@property(nonatomic, readonly, assign) UAInAppMessageAudienceMissBehaviorType missBehavior;

/**
 * Factory method for building audience model from a builder block.
 *
 * @param builderBlock The builder block.
 * @returns `YES` if the builderBlock was able to be applied, otherwise `NO`.
 */
+ (instancetype)audienceWithBuilderBlock:(void(^)(UAInAppMessageAudienceBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

