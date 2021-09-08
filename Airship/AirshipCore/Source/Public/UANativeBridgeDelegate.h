/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UANativeBridgeDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate methods to support the Airship native bridge.
 */
NS_SWIFT_NAME(NativeBridgeDelegate)
@protocol UANativeBridgeDelegate <NSObject>

@required

/**
 * Called when `UAirship.close()` is triggered from the JavaScript environment.
 */
- (void)close;

@end

NS_ASSUME_NONNULL_END
