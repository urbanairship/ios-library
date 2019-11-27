/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if !(__has_include("AirshipLib.h"))
@import AirshipCore;
#else
#import "UALocationModuleLoaderFactory.h"
#import "UAModuleLoader.h"
#import "UALocationProvider.h"
#endif


NS_ASSUME_NONNULL_BEGIN

/**
 * Location module loader.
 */
@interface UALocationModuleLoader : NSObject<UAModuleLoader, UALocationModuleLoaderFactory, UALocationProviderLoader>

@end


NS_ASSUME_NONNULL_END
