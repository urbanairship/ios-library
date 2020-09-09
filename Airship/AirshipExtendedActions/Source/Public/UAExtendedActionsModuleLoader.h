/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAExtendedActionsCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Extended actions module loader.
 * @note For internal use only. :nodoc:
 */
@interface UAExtendedActionsModuleLoader : NSObject<UAModuleLoader, UAExtendedActionsModuleLoaderFactory>

@end

NS_ASSUME_NONNULL_END
