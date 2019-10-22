/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAActionRegistry.h"
#import "UAComponent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal protocol to load optional modules.
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
- (NSArray<UAComponent *> *)components;

@end

NS_ASSUME_NONNULL_END

