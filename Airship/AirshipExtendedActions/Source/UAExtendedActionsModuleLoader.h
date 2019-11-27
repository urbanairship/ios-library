/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UAModuleLoader.h"
#endif

#import "UAExtendedActionsModuleLoaderFactory.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Extended actions module loader.
 */
@interface UAExtendedActionsModuleLoader : NSObject<UAModuleLoader, UAExtendedActionsModuleLoaderFactory>

@end

NS_ASSUME_NONNULL_END
