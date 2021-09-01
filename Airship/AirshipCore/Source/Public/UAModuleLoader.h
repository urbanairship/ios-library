/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent.h"

@class UAActionRegistry;

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal protocol to load optional modules.
 * @note For internal use only. :nodoc:
 */
@protocol UAModuleLoader <NSObject>

@optional

/**
 * Called to register actions during takeOff.
 */
- (void)registerActions:(UAActionRegistry *)registry;

/**
 * Returns the components defined by the module.
 */
- (NSArray<id<UAComponent>> *)components;

@end

NS_ASSUME_NONNULL_END

