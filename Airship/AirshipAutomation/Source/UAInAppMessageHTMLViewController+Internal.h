/* Copyright Airship and Contributors */

#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessageHTMLStyle.h"
#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAAutomationNativeBridgeExtension+Internal.h"

NS_ASSUME_NONNULL_BEGIN


@interface UAInAppMessageHTMLViewController : UIViewController

/**
 * The HTML display content.
 */
@property (nonatomic, strong) UAInAppMessageHTMLDisplayContent *displayContent;

/**
 * The in-app message HTML styling.
 */
@property(nonatomic, strong) UAInAppMessageHTMLStyle *style;

/**
 * The resizable parent in which the HTML view is embedded.
 */
@property (weak, nonatomic) UAInAppMessageResizableViewController *resizableParent;

/**
 * The factory method for creating an HTML controller.
 *
 * @param displayContent The display content.
 * @param style The HTML view styling.
 * @param nativeBridgeExtension The automation native bridge extension.
 *
 * @return a configured UAInAppMessageHTMLViewController instance.
 */
+ (instancetype)htmlControllerWithDisplayContent:(UAInAppMessageHTMLDisplayContent *)displayContent
                                           style:(UAInAppMessageHTMLStyle *)style
                           nativeBridgeExtension:(UAAutomationNativeBridgeExtension *)nativeBridgeExtension;

@end

NS_ASSUME_NONNULL_END
