/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if UA_USE_MODULE_IMPORT
#import <AirshipCore/AirshipCore.h>
#else
#import "UASDKModule.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Accengage SDK module.
 * @note For internal use only. :nodoc:
 */
@interface UAAccengageSDKModule : NSObject<UASDKModule>

@end

NS_ASSUME_NONNULL_END
