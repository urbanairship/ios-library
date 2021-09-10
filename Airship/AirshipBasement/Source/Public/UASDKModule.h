/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal protocol to load optional modules.
 * @note For internal use only. :nodoc:
 */
NS_SWIFT_NAME(SDKModule)
@protocol UASDKModule <NSObject>

/**
 * Called to create the module.
 * @param dependencies Module dependencies.
 * @return The UASDKModule.
 */
+ (nullable id<UASDKModule>)loadWithDependencies:(NSDictionary *)dependencies;

@optional

/**
 * Optional actions plist path.
 */
- (nullable NSString *)actionsPlist;

/**
 * Returns the components defined by the module.
 */
- (NSArray<id<UAComponent>> *)components;

@end


NS_ASSUME_NONNULL_END

