/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UADeferredScheduleResult+Internal.h"
#import "UADeferredScheduleRetryRules+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UADeferredAPIClientResponse : NSObject

@property (nonatomic) NSInteger status;
@property (nonatomic, strong) UADeferredScheduleResult *result;
@property (nonatomic, strong) UADeferredScheduleRetryRules *rules;


/**
 * Factory method.
 * @param status The status code.
 * @param result The result.
 * @param rules The retry rules.
 * @return The response.
 */
+ (instancetype)responseWithStatus:(NSInteger)status
                            result:(nullable UADeferredScheduleResult *)result
                             rules:(nullable UADeferredScheduleRetryRules *)rules;
@end


NS_ASSUME_NONNULL_END
