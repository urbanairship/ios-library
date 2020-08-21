/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Deferred result.
 */
@interface UADeferredScheduleResult : NSObject

/**
 * Audience match flag.
 */
@property (nonatomic, readonly) BOOL isAudienceMatch;

/**
 * Optional message.
 */
@property (nonatomic, readonly, nullable) UAInAppMessage *message;

/**
 * Factory method.
 * @param message The optional message.
 * @param audienceMatch `YES` if the audience matched, otherwise `NO`.
 * @return The result.
 */
+ (instancetype)resultWithMessage:(nullable UAInAppMessage *)message
                    audienceMatch:(BOOL)audienceMatch;
@end

NS_ASSUME_NONNULL_END
