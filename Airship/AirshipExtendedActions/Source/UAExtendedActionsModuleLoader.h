/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if __has_include(<AirshipCore/AirshipCore.h>)
#import <AirshipCore/AirshipCore.h>
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
