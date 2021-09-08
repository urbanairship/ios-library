/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageModalStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Modal in-app message display adapter.
 */
NS_SWIFT_NAME(InAppMessageModalAdapter)
@interface UAInAppMessageModalAdapter : NSObject <UAInAppMessageAdapterProtocol>

/**
 * Modal in-app message display style defaults plist name.
 */
extern NSString *const UAModalStyleFileName;

/**
 * Modal in-app message display style.
 */
@property(nonatomic, strong, nullable) UAInAppMessageModalStyle *style;

@end

NS_ASSUME_NONNULL_END

