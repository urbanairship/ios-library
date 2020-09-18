/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_AIRSHIP_IMPORT
#import <Airship/Airship.h>
#elif UA_USE_MODULE_IMPORT
#import <AirshipCore/AirshipCore.h>
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
