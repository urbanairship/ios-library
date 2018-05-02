/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageFullScreenStyle.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageMediaView;

/**
 * The full screen controller.
 */
@interface UAInAppMessageFullScreenController : NSObject <UIGestureRecognizerDelegate>

/**
 * The factory method for creating a full screen controller.
 *
 * @param identifer The message identifier.
 * @param displayContent The display content.
 * @param mediaView The media view.
 * @param style The full screen styling.
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)fullScreenControllerWithFullScreenMessageID:(NSString *)identifer
                                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                  mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                                      style:(UAInAppMessageFullScreenStyle *)style;

/**
 * The method to show the full screen controller.
 *
 * @param parentView The parent view.
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithParentView:(UIView *)parentView
         completionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END

