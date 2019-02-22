/* Copyright Urban Airship and Contributors */

#import "UAWKWebViewDelegate.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessageHTMLStyle.h"
#import "UAInAppMessageResizableViewController+Internal.h"

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
 * @param messageID The message identifier.
 * @param displayContent The display content.
 * @param style The HTML view styling.
 *
 * @return a configured UAInAppMessageHTMLViewController instance.
 */
+ (instancetype)htmlControllerWithMessageID:(NSString *)messageID
                             displayContent:(UAInAppMessageHTMLDisplayContent *)displayContent
                                      style:(UAInAppMessageHTMLStyle *)style;

@end

NS_ASSUME_NONNULL_END
