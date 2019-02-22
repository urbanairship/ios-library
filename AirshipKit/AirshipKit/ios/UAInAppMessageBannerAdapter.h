/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageBannerStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Banner in-app message display adapter.
 */
@interface UAInAppMessageBannerAdapter : NSObject <UAInAppMessageAdapterProtocol>

/**
 * Banner in-app message display style defaults plist name.
 */
extern NSString *const UABannerStyleFileName;

/**
 * Banner in-app message display style.
 */
@property(nonatomic, strong, nullable) UAInAppMessageBannerStyle *style;

@end

NS_ASSUME_NONNULL_END
