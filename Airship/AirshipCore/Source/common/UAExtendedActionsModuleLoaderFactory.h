/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal extended action module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UAExtendedActionsModuleLoaderFactory <NSObject>

@required

/**
 * Factory method to provide the extended actions module loader.
 * @return A module loader.
 */
+ (id<UAModuleLoader>)extendedActionsModuleLoader;

@end

NS_ASSUME_NONNULL_END

