/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UAAccengageModuleLoaderFactory.h"
#import "UAModuleLoader.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Accengage module loader.
 * @note For internal use only. :nodoc:
 */
@interface UAAccengageModuleLoader : NSObject<UAModuleLoader, UAAccengageModuleLoaderFactory>

@end

NS_ASSUME_NONNULL_END
