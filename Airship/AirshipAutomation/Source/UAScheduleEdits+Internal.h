/* Copyright Airship and Contributors */

#import "UAScheduleEdits.h"

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

@end

NS_ASSUME_NONNULL_END


