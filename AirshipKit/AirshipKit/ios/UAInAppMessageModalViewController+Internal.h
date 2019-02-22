/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageModalDisplayContent.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageModalStyle.h"


NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageMediaView;
@class UAInAppMessageResizableViewController;

/**
 * The modal controller.
 */
@interface UAInAppMessageModalViewController : UIViewController

/**
 * The modal display content.
 */
@property (nonatomic, strong) UAInAppMessageModalDisplayContent *displayContent;

/**
 * The in-app message modal styling.
 */
@property(nonatomic, strong) UAInAppMessageModalStyle *style;

/**
 * The resizable parent in which the modal view is embedded.
 */
@property (weak, nonatomic) UAInAppMessageResizableViewController *resizableParent;

/**
 * The factory method for creating a modal controller.
 *
 * @param identifier The message identifier.
 * @param displayContent The display content.
 * @param mediaView The media view.
 * @param style The modal view styling.
 *
 * @return a configured UAInAppMessageModalView instance.
 */
+ (instancetype)modalControllerWithModalMessageID:(NSString *)identifier
                                   displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                        mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                            style:(nullable UAInAppMessageModalStyle *)style;

@end

NS_ASSUME_NONNULL_END

