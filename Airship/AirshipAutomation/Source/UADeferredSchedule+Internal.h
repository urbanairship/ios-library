/* Copyright Airship and Contributors */

#import "UADeferredSchedule.h"
#import "UAScheduleDeferredData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * UADeferredSchedule extension.
 */
@interface UADeferredSchedule()

/**
 * Creates a schedule with a builder block.
 * @param deferredData The deferred data.
 * @param builderBlock The builder block.
 * @return A schedule.
 */
+ (instancetype)scheduleWithDeferredData:(UAScheduleDeferredData *)deferredData
                            builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END
