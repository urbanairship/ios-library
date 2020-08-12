/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageFullScreenStyle.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageMediaView;

/**
 * The full screen controller.
 */
@interface UAInAppMessageFullScreenViewController : UIViewController <UIGestureRecognizerDelegate>

/**
 * The factory method for creating a full screen controller.
 *
 * @param displayContent The display content.
 * @param mediaView The media view.
 * @param style The full screen styling.
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)fullScreenControllerWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                             mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                                 style:(UAInAppMessageFullScreenStyle *)style;

/**
 * The method to show the full screen view controller.
 *
 * @param completionHandler The completion handler that's called when the show operation completes.
 */
- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

/**
 * The method to show the full screen view controller.
 *
 * @param scene The window scene in which to show the  message.
 * @param completionHandler The completion handler that's called when the show operation completes.
 */
- (void)showWithScene:(UIWindowScene *)scene completionHandler:(void (^)(UAInAppMessageResolution *))completionHandler API_AVAILABLE(ios(13.0));

@end

NS_ASSUME_NONNULL_END

