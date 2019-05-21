/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UARuntimeConfig.h"
#import "UAConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal UARuntimeConfig interface.
 */
@interface UARuntimeConfig()

/**
 * Factory method.
 * @param config the UAConfig instance.
 * @return A runtime config if the provided UAConfig is valid, otherwise nil.
 */
+ (nullable instancetype)runtimeConfigWithConfig:(UAConfig *)config;

/**
 * Init method. Exposed for testing.
 * @param config the UAConfig instance.
 * @return The instance.
 */
- (instancetype)initWithConfig:(UAConfig *)config;

@end

NS_ASSUME_NONNULL_END
