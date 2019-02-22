/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageDisplayContent.h"

@class UAInAppMessageResizableView;
@class UAInAppMessageHTMLViewController;
@class UAInAppMessageModalViewController;
@class UAPadding;


NS_ASSUME_NONNULL_BEGIN

/**
 * A view controller that acts a container for a child in-app message view
 */
@interface UAInAppMessageResizableViewController : UIViewController

/**
 * The flag indicating the state of the resizable view.
 */
@property (nonatomic, assign) BOOL isShowing;

/**
 * The new window created in front of the app's existing window.
 */
@property (strong, nonatomic, nullable) UIWindow *topWindow;

/**
 * The background color to be applied to the shade view when the app is in full screen display.
 */
@property (strong, nonatomic) UIColor *backgroundColor;

/**
 * The constants added to the default spacing between a view and its parent.
 */
@property(nonatomic, strong) UAPadding *additionalPadding;

/**
 * The dismiss icon image resource name.
 */
@property(nonatomic, strong, nullable) NSString *dismissIconResource;

/**
 * The max width in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxWidth;

/**
 * The max height in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxHeight;

/**
 * Flag indicating if the resizable view will display full screen.
 */
@property (nonatomic, assign) BOOL displayFullScreen;

/**
 * Flag indicating the resizable view should display as full screen on compact devices.
 * Defaults to `NO`.
 */
@property(nonatomic, assign) BOOL allowFullScreenDisplay;

/**
 * The resizing container view's border radius.
 */
@property (nonatomic, assign) CGFloat borderRadius;

/**
 * Flag indicating the resizable view should round its borders
 */
@property(nonatomic, assign) BOOL allowBorderRounding;


/**
 * Factory method to initialize a resizable view controller with a child.
 *
 * @param vc The child view controller.
 */
+ (instancetype)resizableViewControllerWithChild:(UIViewController *)vc;

/**
 * The method to show the resizable view controller.
 *
 * @param completionHandler The completion handler that's called when show operation completes.
 */
- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

/**
 * The method to dismiss the resizable view controller.
 *
 * @param resolution The resolution info.
 */
- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution;


@end

NS_ASSUME_NONNULL_END
