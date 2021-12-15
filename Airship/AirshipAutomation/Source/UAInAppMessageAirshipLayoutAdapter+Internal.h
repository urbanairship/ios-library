/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageAdvancedAdapterProtocol+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Airship layout  display adapter.
 */
NS_SWIFT_NAME(InAppMessageAirshipLayoutAdapter)
API_AVAILABLE(ios(13.0))
@interface UAInAppMessageAirshipLayoutAdapter : NSObject <UAInAppMessageAdapterProtocol, UAInAppMessageAdvancedAdapterProtocol>

@end

NS_ASSUME_NONNULL_END
