/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageBannerStyle.h"

@class UAInAppMessageMediaView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The banner controller.
 */
@interface UAInAppMessageBannerController : NSObject <UIGestureRecognizerDelegate>

/**
 * The factory method for creating a banner controller.
 *
 * @param identifier The message identifier.
 * @param displayContent The display content.
 * @param mediaView The media view.
 * @param style The banner style.
 *
 * @return a configured UAInAppMessageBannerView instance.
 */
+ (instancetype)bannerControllerWithBannerMessageID:(NSString *)identifier
                                     displayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                          mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                              style:(nullable UAInAppMessageBannerStyle *)style;

/**
 * The method to show the banner controller.
 *
 * @param parentView The parent view.
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithParentView:(UIView *)parentView completionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END
