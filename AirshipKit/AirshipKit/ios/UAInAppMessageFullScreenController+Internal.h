/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageResolution.h"

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
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)fullScreenControllerWithFullScreenMessageID:(NSString *)identifer
                                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                  mediaView:(UAInAppMessageMediaView * _Nullable)mediaView;

/**
 * The method to show the full screen controller.
 *
 * @param parentView The parent view.
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithParentView:(UIView *)parentView completionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END
