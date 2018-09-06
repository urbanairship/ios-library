/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageBannerStyle.h"

@class UAInAppMessageMediaView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The banner view controller.
 */
@interface UAInAppMessageBannerViewController : UIViewController<UIGestureRecognizerDelegate>

/**
 * The factory method for creating a banner view controller.
 *
 * @param identifier The message identifier.
 * @param displayContent The display content.
 * @param mediaView The media view.
 * @param style The banner style.
 *
 * @return a configured UAInAppMessageBannerViewController instance.
 */
+ (instancetype)bannerViewControllerWithIdentifier:(NSString *)identifier
                                    displayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                         mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                             style:(nullable UAInAppMessageBannerStyle *)style;

/**
 * The method to show the banner view controller.
 *
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler;

@end

NS_ASSUME_NONNULL_END

