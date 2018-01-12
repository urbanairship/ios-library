/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageModalDisplayContent.h"
#import "UAInAppMessageResolution.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageMediaView;

/**
 * The modal controller.
 */
@interface UAInAppMessageModalViewController : UIViewController

/**
 * The factory method for creating a modal controller.
 *
 * @param identifer The message identifier.
 * @param displayContent The display content.
 * @param mediaView The media view.
 *
 * @return a configured UAInAppMessageModalView instance.
 */
+ (instancetype)modalControllerWithModalMessageID:(NSString *)identifer
                                   displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                        mediaView:(UAInAppMessageMediaView * _Nullable)mediaView;

/**
 * The method to show the modal controller.
 *
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END

