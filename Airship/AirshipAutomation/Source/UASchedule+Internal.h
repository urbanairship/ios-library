/* Copyright Airship and Contributors */

#import "UASchedule.h"
#import "UAScheduleDeferredData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for UASchedule.
 */
@interface UASchedule ()

@property (nullable, nonatomic, retain) NSString *dataJSONString;

/**
 * Creates a schedule with a builder block.
 * @param deferredData The deferred data.
 * @param builderBlock The builder block.
 * @return A schedule.
 */
+ (instancetype)scheduleWithDeferredData:(UAScheduleDeferredData *)deferredData
                       builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock;


/**
 * Creates a schedule with a builder block and type from JSON.
 * @param type The schedule type.
 * @param JSON The data JSON.
 * @param builderBlock The builder block.
 * @return A schedule or nil if the type is invalid.
 */
+ (nullable instancetype)scheduleWithType:(UAScheduleType)type
                                 dataJSON:(id)JSON
                             builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END

