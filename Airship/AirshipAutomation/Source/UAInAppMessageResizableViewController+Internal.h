/* Copyright Airship and Contributors */

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
 * The resizable container
 */
@property (strong, nonatomic) IBOutlet UAInAppMessageResizableView *resizableContainer;

/**
 * The background color to be applied to the shade view when the app is in full screen display.
 */
@property (strong, nonatomic) UIColor *backgroundColor;

/**
 * The constants added to the default spacing between a view and its parent.
 */
@property(nonatomic, strong) UAPadding *additionalPadding;

@property(nonatomic, assign) BOOL allowMaxHeight;

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
 * Flag indicating the resizable view should extend display as full screen on large devices.
 * Defaults to `NO`.
 */
@property(nonatomic, assign) BOOL extendFullScreenLargeDevice;

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
 * Factory method to initialize a resizable view controller with a child and instrinsic
 * size properties
 *
 * @param vc The child view controller.
 * @param size The intrinsic size of the resizable view.
 * @param aspectLock Flag indicating if the HTML view should lock its aspect ratio when resizing to fit the screen.
 */
+ (instancetype)resizableViewControllerWithChild:(UIViewController *)vc
                                            size:(CGSize)size
                                      aspectLock:(BOOL)aspectLock;

/**
 * The method to show the resizable view controller.
 *
 * @param completionHandler The completion handler that's called when the show operation completes.
 */
- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution *))completionHandler;

/**
 * The method to show the resizable view controller.
 *
 * @param scene The window scene in which to show the message.
 * @param completionHandler The completion handler that's called when the show operation completes.
 */
- (void)showWithScene:(UIWindowScene *)scene completionHandler:(void (^)(UAInAppMessageResolution *))completionHandler API_AVAILABLE(ios(13.0));

/**
 * The method to dismiss the resizable view controller.
 *
 * @param resolution The resolution info.
 */
- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution;

/**
 * The method to dismiss the resizable view controller without a resolution.
 *
 * @note: This is necessary because the view controller currently does the final processing on
 * the message URL. If the message URL fails to result in a message from the list, the
 * view will be dismissed without a resolution.
 */
- (void)dismissWithoutResolution;

@end

NS_ASSUME_NONNULL_END
