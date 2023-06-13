/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent.h"
#import "UALegacyAction.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal protocol to load optional modules.
 * @note For internal use only. :nodoc:
 */
@protocol UALegacySDKModule <NSObject>

/**
 * Called to create the module.
 * @param dependencies Module dependencies.
 * @return The UALegacySDKModule
 */
+ (nullable id<UALegacySDKModule>)loadWithDependencies:(NSDictionary *)dependencies;

@optional

/**
 * Optional legacy actions.
 */
- (NSArray<id<UALegacyAction>> *)actions;

/**
 * Returns the components defined by the module.
 */
- (NSArray<id<UAComponent>> *)components;

@end


NS_ASSUME_NONNULL_END

