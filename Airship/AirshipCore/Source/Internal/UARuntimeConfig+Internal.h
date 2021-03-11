/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UARuntimeConfig.h"
#import "UAConfig.h"
#import "UARemoteConfigURLManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal UARuntimeConfig interface.
 */
@interface UARuntimeConfig()

/**
 * Factory method.
 * @param config the UAConfig instance.
 * @param urlManager the URL config manager.
 * @return A runtime config if the provided UAConfig is valid, otherwise nil.
 */
+ (nullable instancetype)runtimeConfigWithConfig:(UAConfig *)config urlManager:(UARemoteConfigURLManager *)urlManager;

/**
 * Init method. Exposed for testing.
 * @param config the UAConfig instance.
 * @param urlManager the URL config manager.
 * @return The instance.
 */
- (instancetype)initWithConfig:(UAConfig *)config urlManager:(UARemoteConfigURLManager *)urlManager;

@end

NS_ASSUME_NONNULL_END
