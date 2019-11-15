/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAInAppMessageAssets.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageAssets()

/**
 * Factory method.
 *
 * @param rootURL Root URL in which to store assets.
 */
+ (instancetype)assets:(NSURL *)rootURL;

/**
 * Clear assets from cache
 */
- (void)clearAssets;

@end

NS_ASSUME_NONNULL_END
