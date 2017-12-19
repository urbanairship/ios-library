/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageFullScreenDisplayContent.h"
NS_ASSUME_NONNULL_BEGIN

/**
 * The full screen controller.
 */
@interface UAInAppMessageFullScreenController : NSObject <UIGestureRecognizerDelegate>

/**
 * The factory method for creating a full screen controller.
 *
 * @param identifer The message identifier.
 * @param displayContent The display content.
 * @param image The image.
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)fullScreenControllerWithFullScreenMessageID:(NSString *)identifer
                                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                      image:(UIImage * _Nullable)image;

/**
 * The method to show the full screen controller.
 *
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)show:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
