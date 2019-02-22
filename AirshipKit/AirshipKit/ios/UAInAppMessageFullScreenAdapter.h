/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageFullScreenStyle.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * Full screen in-app message display adapter.
 */
@interface UAInAppMessageFullScreenAdapter : NSObject <UAInAppMessageAdapterProtocol>

/**
 * Full screen in-app message display style defaults plist name.
 */
extern NSString *const UAFullScreenStyleFileName;

/**
 * Full screen in-app message display style.
 */
@property(nonatomic, strong, nullable) UAInAppMessageFullScreenStyle *style;

@end

NS_ASSUME_NONNULL_END

