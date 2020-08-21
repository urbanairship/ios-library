/* Copyright Airship and Contributors */

#import "UAScheduleEdits.h"
#import "UAScheduleDeferredData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

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
 * Creates edits that also updates the schedule's data as deferred.
 * @param deferred The deferred data.
 * @param builderBlock The builder block.
 * @return The schedule edits.
 */
+ (instancetype)editsWithDeferredData:(UAScheduleDeferredData *)deferred
                         builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

