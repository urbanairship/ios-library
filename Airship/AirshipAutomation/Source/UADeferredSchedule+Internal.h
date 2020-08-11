/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UASchedule.h"
#import "UAScheduleDeferredData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A deferred schedule.
 */
@interface UADeferredSchedule : UASchedule

/**
 * Schedule's deferred data.
 */
@property(nonatomic, readonly) UAScheduleDeferredData *deferredData;


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
