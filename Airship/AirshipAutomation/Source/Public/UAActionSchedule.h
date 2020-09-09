/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UASchedule.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An actions schedule.
 */
@interface UAActionSchedule : UASchedule

/**
 * Schedule's actions.
 */
@property(nonatomic, readonly) NSDictionary *actions;

/**
 * Creates an action schedule with a builder block.
 * @param actions The actions.
 * @param builderBlock The builder block.
 * @return A schedule.
 */
+ (instancetype)scheduleWithActions:(NSDictionary *)actions
                       builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END
