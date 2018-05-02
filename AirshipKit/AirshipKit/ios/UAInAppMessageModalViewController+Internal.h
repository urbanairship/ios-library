/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageModalDisplayContent.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageModalStyle.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageMediaView;

/**
 * The modal controller.
 */
@interface UAInAppMessageModalViewController : UIViewController

/**
 * Modal Container. Used to add external padding to the modal view.
 */
@property(strong, nonatomic) IBOutlet UIView *modalContainer;

/**
 * The factory method for creating a modal controller.
 *
 * @param identifer The message identifier.
 * @param displayContent The display content.
 * @param mediaView The media view.
 * @param style The modal view styling.
 *
 * @return a configured UAInAppMessageModalView instance.
 */
+ (instancetype)modalControllerWithModalMessageID:(NSString *)identifer
                                   displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                        mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                            style:(nullable UAInAppMessageModalStyle *)style;

/** 
 * The method to show the modal controller.
 *
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END

