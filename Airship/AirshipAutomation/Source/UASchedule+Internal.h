/* Copyright Airship and Contributors */

#import "UASchedule.h"
#import "UAScheduleDeferredData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UAScheduleType) {

    /**
     * In-app message type.
     */
    UAScheduleTypeInAppMessage,

    /**
     * Actions type.
     */
    UAScheduleTypeActions,

    /**
     * Deferred type.
     */
    UAScheduleTypeDeferred
};

/**
 * Builder class for UASchedule.
 */
@interface UASchedule ()

/**
 * The schedule type.
 */
@property(nonatomic, readonly) UAScheduleType type;

/**
 * Schedule data.
 */
@property(nonatomic, readonly) id data;

@property(nonatomic, readonly) NSString *dataJSONString;

- (instancetype)initWithData:(id)data
                        type:(UAScheduleType)scheduleType
                     builder:(UAScheduleBuilder *)builder;

@end

NS_ASSUME_NONNULL_END

