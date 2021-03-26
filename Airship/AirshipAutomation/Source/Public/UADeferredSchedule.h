/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UASchedule.h"
#import "UAScheduleDeferredData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A deferred schedule.
 */
@interface UADeferredSchedule : UASchedule

/**
 * Schedule's deferred data.
 */
@property(nonatomic, readonly) UAScheduleDeferredData *deferredData;

@end

NS_ASSUME_NONNULL_END
