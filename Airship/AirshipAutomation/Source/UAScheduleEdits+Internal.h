/* Copyright Airship and Contributors */

#import "UAScheduleEdits.h"
#import "UAScheduleDeferredData.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAScheduleEditsBuilder()

/**
 * The campaigns info.
 */
@property (nullable, nonatomic, copy) NSDictionary *campaigns;


/**
 * The reporting context.
 */
@property (nullable, nonatomic, copy) NSDictionary *reportingContext;


/**
 * Audience JSON
 */
@property (nullable, nonatomic, copy) NSDictionary *audienceJSON;


/**
 * The frequency constraint IDs.
 */
@property (nullable, nonatomic, copy) NSArray<NSString *> *frequencyConstraintIDs;

/**
 * The schedule's message type.
 */
@property(nonatomic, copy, nullable) NSString *messageType;

/**
 * Indicates if schedule could be in holdout group
 */
@property(nonatomic, strong, nullable) NSNumber *bypassHoldoutGroups;

/**
 * New user evaluation date
 */
@property(nonatomic, nullable) NSDate *isNewUserEvaluationDate;

/**
 * Product id for metered usage
 */
@property(nonatomic, nullable) NSString *productId;

@end

@interface UAScheduleEdits ()

/**
 * Schedule's data as a JSON string.
 */
@property(nonatomic, readonly, nullable) NSString *data;

/**
 * Schedule data type.
 */
@property(nonatomic, readonly, nullable) NSNumber *type;

/**
 * The schedule's message type.
 */
@property(nonatomic, readonly, nullable) NSString *messageType;

/**
 * Indicates if schedule could be in holdout group
 */
@property(nonatomic, readonly, nullable) NSNumber *bypassHoldoutGroups;

/**
 * New user evaluation date
 */
@property(nonatomic, readonly, nullable) NSDate *isNewUserEvaluationDate;


/**
 * Campaigns info.
 */
@property(nonatomic, readonly, nullable) NSDictionary *campaigns;

/**
 * Reporting context.
 */
@property(nonatomic, readonly, nullable) NSDictionary *reportingContext;

/**
 * Audience JSON
 */
@property(nonatomic, readonly, nullable) NSDictionary *audienceJSON;


/**
 * Frequency constraint IDs.
 */
@property(nonatomic, readonly, nullable) NSArray<NSString *> *frequencyConstraintIDs;

/**
 * Product id for metered usage
 */
@property(nonatomic, nullable, readonly) NSString *productId;


/**
 * Creates edits that also updates the schedule's data as deferred.
 * @param deferred The deferred data.
 * @param builderBlock The builder block.
 * @return The schedule edits.
 */
+ (instancetype)editsWithDeferredData:(UAScheduleDeferredData *)deferred
                         builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

