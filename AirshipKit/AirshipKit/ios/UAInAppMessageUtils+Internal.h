/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAInAppMessageButtonInfo.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButton+Internal.h"

@interface UAInAppMessageUtils : NSObject

/**
 * Applies button info to a button.
 *
 * @param buttonInfo The button info.
 * @param button The button.
 */
+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo button:(UAInAppMessageButton *)button;

/**
 * Applies text info to a text label.
 *
 * @param textInfo The text info.
 * @param label The label.
 */
+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo label:(UILabel *)label;

/**
 * Constrains the contained view to the center of the container with equivalent size
 *
 * This method has the side effect of setting both view parameters translatesAutoresizingMasksIntoConstraints to NO.
 * This is done to ensure that autoresizing mask constraints do not conflict with the centering constraints.
 * 
 * @param container The container view.
 * @param contained The contained view.
 */
+ (void)applyContainerConstraintsToContainer:(UIView *)container containedView:(UIView *)contained;

/**
 * Caches url data contents using a background thread. Calls completion handler on main thread
 * with cache key under which the cached contents are stored.
 *
 * @param url The url of the data contents you wish to cache.
 * @param cache The cache instance.
 * @param completionHandler The completion handler with cache key for pulling conents out of cache.
 */
+ (void)prefetchContentsOfURL:(NSURL *)url WithCache:(NSCache *)cache completionHandler:(void (^)(NSString *cacheKey))completionHandler;

@end
