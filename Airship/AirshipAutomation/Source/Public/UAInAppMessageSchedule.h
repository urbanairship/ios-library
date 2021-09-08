/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UASchedule.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An in-app message schedule.
 */
NS_SWIFT_NAME(InAppMessageSchedule)
@interface UAInAppMessageSchedule : UASchedule

/**
 * Schedule's message.
 */
@property(nonatomic, readonly) UAInAppMessage *message;

/**
 * Creates a schedule with a builder block.
 * @param message The in-app message.
 * @param builderBlock The builder block.
 * @return A schedule.
 */
+ (instancetype)scheduleWithMessage:(UAInAppMessage *)message
                       builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END
