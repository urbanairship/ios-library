/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if __has_include(<AirshipKit/AirshipLib.h>)
#import <AirshipKit/AirshipLib.h>
#elif __has_include("AirshipLib.h")
#import "AirshipLib.h"
#else
@import AirshipKit;
#endif


NS_ASSUME_NONNULL_BEGIN

/**
 * Location module loader.
 */
@interface UALocationModuleLoader : NSObject<UAModuleLoader, UALocationModuleLoaderFactory>

@end


NS_ASSUME_NONNULL_END
