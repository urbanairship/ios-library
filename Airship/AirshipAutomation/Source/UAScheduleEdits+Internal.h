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
 * The frequency constraint IDs.
 */
@property (nullable, nonatomic, copy) NSArray<NSString *> *frequencyConstraintIDs;


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
 * Campaigns info.
 */
@property(nonatomic, readonly, nullable) NSDictionary *campaigns;

/**
 * Reporting context.
 */
@property(nonatomic, readonly, nullable) NSDictionary *reportingContext;


/**
 * Frequency constraint IDs.
 */
@property(nonatomic, readonly, nullable) NSArray<NSString *> *frequencyConstraintIDs;


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

