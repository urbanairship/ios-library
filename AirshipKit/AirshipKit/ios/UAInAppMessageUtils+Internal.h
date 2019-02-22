/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAInAppMessageButtonInfo.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButton+Internal.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageDismissButton+Internal.h"

@interface UAInAppMessageUtils : NSObject

/**
 * Applies button info to a button.
 *
 * @param buttonInfo The button info.
 * @param style The button styling.
 * @param button The button.
 * @param buttonMargin Specify the top and bottom margin between the edge of the button and the edge of the label
 */
+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                  style:(UAInAppMessageButtonStyle *)style
                 button:(UAInAppMessageButton *)button
           buttonMargin:(CGFloat)buttonMargin;

/**
 * Applies text info to a text label.
 *
 * @param textInfo The text info.
 * @param style The text styling.
 * @param label The label.
 */
+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo style:(UAInAppMessageTextStyle *)style label:(UILabel *)label;

/**
 * Constrains the buttom image view to default size and to the lower left hand corner of the touchable button space.
 *
 * This method has the side effect of setting both views' translatesAutoresizingMasksIntoConstraints parameters to NO.
 * This is done to ensure that autoresizing mask constraints do not conflict with the centering constraints.
 *
 * @param container The container view.
 * @param contained The contained image view view.
 */
+ (void)applyCloseButtonImageConstraintsToContainer:(UIView *)container closeButtonImageView:(UIImageView *)contained;

/**
 * Caches url data contents using a background thread. Calls completion handler on main thread
 * with cache key under which the cached contents are stored.
 *
 * @param url The url of the data contents you wish to cache.
 * @param cache The cache instance.
 * @param completionHandler The completion handler with cache key for pulling conents out of cache, and a result status.
 */
+ (void)prefetchContentsOfURL:(NSURL *)url WithCache:(NSCache *)cache completionHandler:(void (^)(NSString *cacheKey, UAInAppMessagePrepareResult result))completionHandler;

/**
 * Runs actions for a button.
 *
 * @param button The button.
 */
+ (void)runActionsForButton:(UAInAppMessageButton *)button;

/**
 * Creates an NSCache for the adapter's media.
 *
 * @return The NSCache
 */
+ (NSCache *)createImageCache;

/**
 * Applies padding on the view to match the provided padding style object.
 *
 * @param padding The padding style object
 * @param view A view with constraints to apply padding to
 * @param replace If YES padding will be replaced instead of added to.
 */
+ (void)applyPaddingToView:(UIView *)view padding:(UAPadding *)padding replace:(BOOL)replace;

/**
 * Replaces view constraint constants matching the provided attribute with the provided padding.
 *
 * @param attribute The attribute type that should be padded
 * @param view A view with constraints to apply padding to
 * @param padding The padding to add to constraints matching the attribute type
 * @param replace If YES padding will be replaced instead of added to.
*/
+ (void)applyPaddingForAttribute:(NSLayoutAttribute)attribute onView:(UIView *)view padding:(CGFloat)padding replace:(BOOL)replace;

/**
 * Prepares in-app message to display.
 *
 * @param media media info object for this message
 * @param imageCache the cache for images
 * @param completionHandler the completion handler to be called when media is ready.
 */
+ (void)prepareMediaView:(UAInAppMessageMediaInfo *)media imageCache:(NSCache *)imageCache completionHandler:(void (^)(UAInAppMessagePrepareResult, UAInAppMessageMediaView *))completionHandler;

/**
 * Informs the adapter of the ready state of the in-app message immediately before display.
 *
 * @param media media info object for this message
 * @return `YES` if the in-app message is ready, `NO` otherwise.
 */
+ (BOOL)isReadyToDisplayWithMedia:(UAInAppMessageMediaInfo *)media;

/**
 * Normalizes style dictionaries by stripping out white space
 *
 * @param keyedValues The style dictionary to be normalized.
 * @return The normalized dictionary of style values.
 */
+ (NSDictionary *)normalizeStyleDictionary:(NSDictionary *)keyedValues;


/**
 * Checks if binary data represents a gif.
 *
 * @param data The image data to be checked.
 * @return YES if binary data represesents a gif, NO otherwise.
 */
+ (BOOL)isGifData:(NSData *)data;


@end
