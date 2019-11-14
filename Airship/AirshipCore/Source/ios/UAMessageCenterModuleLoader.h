/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAMessageCenterModuleLoaderFactory.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Message Center module loader.
 */
@interface UAMessageCenterModuleLoader : NSObject<UAModuleLoader, UAMessageCenterModuleLoaderFactory>

@end

NS_ASSUME_NONNULL_END
