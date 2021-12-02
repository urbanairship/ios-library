/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol UAInAppMessageAdvancedAdapterProtocol <UAInAppMessageAdapterProtocol>

/**
 * Displays the in-app message.
 *
 * @param onDisplay A callback when a view is displayed.
 * @param onDismiss A callback when a view is dismissed.
 */
- (void)display:(void (^)(NSDictionary *))onDisplay
      onDismiss:(void (^)(UAInAppMessageResolution *, NSDictionary *))onDismiss;

@end

NS_ASSUME_NONNULL_END
