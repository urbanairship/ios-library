/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageModalDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The modal controller.
 */
@interface UAInAppMessageModalViewController : UIViewController

/**
 * The factory method for creating a modal controller.
 *
 * @param identifer The message identifier.
 * @param displayContent The display content.
 * @param image The image.
 *
 * @return a configured UAInAppMessageModalView instance.
 */
+ (instancetype)modalControllerWithModalMessageID:(NSString *)identifer
                                             displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                                      image:(UIImage * _Nullable)image;

/**
 * The method to show the modal controller.
 *
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)show:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END

