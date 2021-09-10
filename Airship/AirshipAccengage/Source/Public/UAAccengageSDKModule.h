/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if __has_include("AirshipBasement/AirshipBasement.h")
#import <AirshipBasement/AirshipBasement.h>
#else
#import "AirshipBasementLib.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Accengage SDK module.
 * @note For internal use only. :nodoc:
 */
@interface UAAccengageSDKModule : NSObject<UASDKModule>

@end

NS_ASSUME_NONNULL_END
