/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Deferred schedule retry rules.
 */
@interface UADeferredScheduleRetryRules: NSObject

/**
 * Optional redirection location
 */
@property (nonatomic, readonly, copy, nullable) NSString *location;

/**
 * Optional retry time.
 */
@property (nonatomic, readonly) NSTimeInterval retryTime;

/**
 * Factory method.
 * @param location The optional location.
 * @param retryTime The optional retry time.
 * @return The rules.
 */
+ (instancetype)rulesWithLocation:(nullable NSString *)location
                        retryTime:(NSTimeInterval)retryTime;

@end

NS_ASSUME_NONNULL_END
